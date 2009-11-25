module Language.Ruby.Hubris.GHCBuild (ghcBuild, defaultGHCOptions, GHCOptions(..)) where
import Config
import Debug.Trace
import DynFlags
import GHC
import GHC.Paths
import Outputable
import StringBuffer
import System.Process
import Control.Monad(forM_)
import System.IO(hPutStr, hClose, openTempFile)
import System( exitWith, system)
import System.Exit

newtype GHCOptions = GHCOptions { strict :: Bool }
defaultGHCOptions = GHCOptions { strict = True }
type Filename = String

genHaskellFile :: String -> IO String
genHaskellFile code = do (name, handle) <- openTempFile "/tmp" "hubris_XXXXX.hs"
                         hPutStr handle code
                         hClose handle
                         return name

-- sh = showSDoc . ppr
-- this one's a bit tricky: we _could_ use the GHC api, but i don't care too much.
-- let's keep it simple.
--
-- ok, new plan: handling it the filthy way is awful.
--
-- We do need rshim.o, but it's packaged in the hubris lib, with any luck.
ghcBuild :: Filename -> String -> String -> [Filename] -> [Filename] -> [String]-> IO (Maybe (ExitCode,String))
ghcBuild libFile immediateSource modName extra_sources c_sources args =
       do putStrLn ("modname is " ++ modName)
          -- let c_wrapper = modName ++ ".aux.o"
          -- eesh, this is awful...
          -- doOrDie $ System.system("gcc -c -I/opt/local/include/ruby-1.9.1 -o " ++ c_wrapper ++ " " ++ unwords c_sources)
          haskellSrcFile <- genHaskellFile immediateSource
          noisySystem ghc $ ["--make", "-shared", "-dynamic",  "-o", libFile, "-optl-Wl,-rpath," ++ libdir,
                             "-lHSrts-ghc" ++ Config.cProjectVersion, haskellSrcFile, "-I/opt/local/include/ruby-1.9.1"] 
                             ++ extra_sources ++ c_sources ++ args
--           defaultErrorHandler defaultDynFlags $ do
--           res <- runGhc (Just libdir) $ do
--             dflags <- getSessionDynFlags

--             (newflags, leftovers, warnings) <- GHC.parseDynamicFlags dflags 
--                                                $ map noLoc $ [ "-shared", "-o",libFile,"-optl-Wl,-rpath," ++ libdir, 
--                                                               "-lHSrts-ghc" ++ Config.cProjectVersion]
--             trace ("left2: " ++ sh leftovers) $ trace ("warns2: " ++ (sh warnings)) $ setSessionDynFlags newflags

--             forM_ (haskellSrcFile:extra_sources)  (\file -> guessTarget file Nothing >>= addTarget) 

--             load LoadAllTargets
--           -- doOrDie $ System.system("ld -dylib -flat_namespace -o " ++ libFile ++ " " ++ unwords ["foo"++ libFile, c_wrapper])
--           print res
--           return (case res of
--                   Succeeded -> True
--                   _ -> False)

noisySystem :: String -> [String] -> IO (Maybe (ExitCode, String))
noisySystem cmd args = 
    do putStrLn $ unwords (cmd:args)
       (errCode, out, err) <- readProcessWithExitCode cmd args ""
       return $ if (errCode == ExitSuccess)
              then Nothing
              else Just (errCode, unlines ["output: " ++ out, "error: " ++ err])

-- doOrDie :: IO ExitCode -> IO ()
-- doOrDie action = do res <- action
--                     case res of
--                       ExitSuccess -> return ()
--                       i -> exitWith i