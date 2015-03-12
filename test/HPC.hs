module Main (main) where

import Data.List
import System.Exit
import Text.XML.Light
import Data.Maybe
import System.Process
import System.Directory

expected :: Fractional a => a
expected = 85

simpleQName :: String -> QName
simpleQName name = QName{qName=name, qURI=Nothing, qPrefix=Nothing}

usefulMetrics :: QName -> Bool
usefulMetrics name = name `elem` [
  simpleQName "exprs",
  simpleQName "booleans",
  simpleQName "alts",
  simpleQName "local",
  simpleQName "toplevel"]

extractValues :: Element -> (String,String)
extractValues element = (
  fromMaybe ("no string"::String) (findAttrBy (\name -> name == simpleQName "boxes") element),
  fromMaybe ("no string"::String) (findAttrBy (\name -> name == simpleQName "count") element))

calculatePercentages :: (String,String) -> Float
calculatePercentages tuple =
  100 *
  (read (snd tuple) :: Float) /
  (read (fst tuple) :: Float)

coverageOk :: [Float] -> Bool
coverageOk values = (realToFrac (sum values) / genericLength values) > (expected :: Double)
--coverageOk = all (> expected)

hpc :: String -> Bool -> IO String
hpc tixFile True  = readProcess "hpc" ["report", tixFile, "--include=Numeric.Euler.Primes", "--xml-output"] ""
hpc tixFile False = readProcess "hpc" ["report", tixFile, "--include=Numeric.Euler.Primes"] ""

readCoverageFrom :: String -> IO ()
readCoverageFrom tixFile = do
  s <- hpc tixFile True
  case parseXMLDoc s of 
   Nothing -> error "Failed to parse xml. Try running HPC manually..."
   Just doc -> let elements = filterChildrenName usefulMetrics (head $ elChildren doc)
                   values = map extractValues elements
                   percents = map calculatePercentages values
               in if coverageOk percents
                  then exitSuccess
                  else do
                    hpcOutput <- hpc tixFile False
                    putStr hpcOutput >> exitFailure

main :: IO ()
main = do
  specExists <- doesFileExist "./spec.tix"
  if specExists 
  then readCoverageFrom ("./spec.tix" :: String)
  else readCoverageFrom ("./dist/hpc/tix/spec/spec.tix" :: String)

