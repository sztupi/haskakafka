module Main (main) where

import Data.Maybe (fromJust)
import qualified Distribution.PackageDescription as PD
import Distribution.Simple (confHook, defaultMainWithHooks, simpleUserHooks)
import Distribution.Simple.LocalBuildInfo ( LocalBuildInfo, localPkgDescr )
import Distribution.Simple.Setup ( ConfigFlags )
import System.Directory ( getCurrentDirectory )
import System.FilePath ((</>))


main :: IO ()
main = defaultMainWithHooks simpleUserHooks {
           confHook = confHookWithRelativeIncludeAndLib
       }

confHookWithRelativeIncludeAndLib :: (PD.GenericPackageDescription, PD.HookedBuildInfo)
                                  -> ConfigFlags
                                  -> IO LocalBuildInfo
confHookWithRelativeIncludeAndLib (desc,buildInfo) flags = do
  origBuildInfo <- confHook simpleUserHooks (desc,buildInfo) flags
  let origPkgDescr = localPkgDescr origBuildInfo
      origLibrary  = fromJust $ PD.library origPkgDescr
      origLibBuildInfo = PD.libBuildInfo origLibrary
  cwd <- getCurrentDirectory
  return origBuildInfo {
    localPkgDescr = origPkgDescr {
        PD.library = Just $ origLibrary {
            PD.libBuildInfo = origLibBuildInfo {
                  PD.extraLibDirs = (cwd </> "lib") : PD.extraLibDirs origLibBuildInfo
                , PD.includeDirs = (cwd </> "include") : PD.includeDirs origLibBuildInfo
                }
            }
        }
    }
