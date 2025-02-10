import qualified Data.Text as Text
import Frontend
import Common.Route
import Obelisk.Frontend
import Obelisk.Route.Frontend
import Reflex.Dom

main :: IO ()
main = do
  case checkEncoder fullRouteEncoder of
    Left err -> error $ "frontend:main: " <> Text.unpack err
    Right validFullEncoder -> run $ runFrontend validFullEncoder frontend
