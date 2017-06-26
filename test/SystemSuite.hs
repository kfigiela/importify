module Main where

import           Universum

import           Data.List             (isPrefixOf, isSuffixOf, sort)
import qualified Data.Text             as T
import           Importify.Common      (Identifier (..), parseForImports)
import           Importify.Main        (collectUnusedIds, doSource)
import           Language.Haskell.Exts (ImportDecl (..), ModuleHeadAndImports (..),
                                        NonGreedy (..), ParseResult (..),
                                        SrcSpanInfo (..), fromParseResult, parse,
                                        prettyPrint)
import           System.Directory      (listDirectory)
import           Test.Hspec            (Spec, describe, hspec, runIO, shouldBe, specify)

main :: IO ()
main = do
    testFiles <- filter (\file ->
                             (isPrefixOf "Test" file) &&
                             (isSuffixOf ".hs" file))
                    <$> (listDirectory $ toString testDirectory)
    hspec $ spec testFiles

spec :: [FilePath] -> Spec
spec testFiles = do
    describe "importify file" $ do
        mapM_ (makeTest . (toString testDirectory ++)) $ sort testFiles


makeTest :: FilePath -> Spec
makeTest file = do
    testFileContents <- runIO $ readFile file
    let (expectedUnusedSymbols, expectedUsedImports) = loadTestData testFileContents

    unusedIds <- runIO $ uncurry collectUnusedIds $ parseForImports [] testFileContents
    let actualUnusedSymbols = sort $ map getIdentifier unusedIds
    importifiedFile <- runIO $ doSource testFileContents
    let (_, actualUsedImports) = parseForImports [] importifiedFile

    specify (file ++ " has correct unused symbols") $
        actualUnusedSymbols `shouldBe` expectedUnusedSymbols
    specify (file ++ " has correct imports") $
        makeSortedImports actualUsedImports `shouldBe` makeSortedImports expectedUsedImports

loadTestData :: Text -> ([String], [ImportDecl SrcSpanInfo])
loadTestData testFileContents =
    let unused:imports = takeWhile (T.isPrefixOf "--") $ lines testFileContents
    in (parseUnused $ toText unused, parseImports $ map toText imports)

makeSortedImports :: [ImportDecl SrcSpanInfo] -> [Text]
makeSortedImports = sort . map (toText . prettyPrint)

parseUnused :: Text -> [String]
parseUnused = map toString . sort . filter (/= "") . map T.strip . T.splitOn "," . uncomment

parseImports :: [Text] -> [ImportDecl SrcSpanInfo]
parseImports imports =
    let src = unlines $ map uncomment imports
        parseResult :: ParseResult (NonGreedy (ModuleHeadAndImports SrcSpanInfo))
        parseResult = parse $ toString src
        NonGreedy (ModuleHeadAndImports _ _pragma _head importDecls) =
            fromParseResult parseResult
    in importDecls

uncomment :: Text -> Text
uncomment = T.drop 3

testDirectory :: Text
testDirectory = "test/system/"