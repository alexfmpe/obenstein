module Backend where

import Obelisk.Backend
import Obelisk.Frontend
import Obelisk.Route
import Obelisk.Run (run, defaultRunApp, runServeAsset)
import System.Directory

import Common.Route
import Frontend

backend :: Backend BackendRoute FrontendRoute
backend = Backend
  { _backend_run = \serve -> serve $ const $ return ()
  , _backend_routeEncoder = fullRouteEncoder
  }

dev :: FilePath -> IO ()
dev rootDir = runAppDev rootDir backend frontend

runAppDev :: FilePath -> Backend backendRoute frontendRoute -> Frontend (R frontendRoute) -> IO ()
runAppDev rootDir b f = do
  let
    configsParent = rootDir
    assetsParent = rootDir

  withCurrentDirectory configsParent $
    run $ defaultRunApp b f $ runServeAsset $ assetsParent <> "/static"
