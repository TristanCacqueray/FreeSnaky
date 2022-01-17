module Tui where

import Brick
import Brick.BChan
import qualified Brick.Widgets.Border as B
import qualified Brick.Widgets.Border.Style as BS
import Control.Concurrent (forkIO, threadDelay)
import qualified Graphics.Vty as V
import Relude
import Snake
  ( Coord (Coord),
    Direction (DOWN, LEFT, RIGHT, UP),
    Item (SB),
    SnakeBody (SnakeBody),
    WMap (mHeight, mSnake, mWidth),
    getMap,
    mkMap,
    moveSnake,
    setSnakeDirection,
  )

data Tick = Tick

data Name = MainView deriving (Eq, Ord, Show)

newtype AppState = AppState {sMap :: WMap}

drawUI :: AppState -> [Widget Name]
drawUI s = [withBorderStyle BS.unicodeBold $ B.borderWithLabel (str "Free Snaky") $ vBox rows]
  where
    rows = [hBox $ cellsInRow r | r <- [0 .. height -1]]
    cellsInRow y = [drawCoord (x, y) | x <- [0 .. width -1]]
    drawCoord (x, y) = case m !!? x of
      Just r -> case r !!? y of
        Just (Just (SB _)) -> str "o"
        Just _ -> str " "
        Nothing -> str " Out of bounds"
      Nothing -> error "Out of bounds"
    height = mHeight $ sMap s
    width = mWidth $ sMap s
    m = getMap (sMap s)

handleEvent :: AppState -> BrickEvent Name Tick -> EventM Name (Next AppState)
handleEvent s (VtyEvent (V.EvKey V.KEsc [])) = halt s
handleEvent s (AppEvent Tick) = do
  let smap = sMap s
      newSnake = moveSnake $ mSnake smap
      newState = smap {mSnake = newSnake}
  continue s {sMap = newState}
handleEvent s (VtyEvent (V.EvKey V.KRight [])) = handleDirEvent s RIGHT
handleEvent s (VtyEvent (V.EvKey V.KLeft [])) = handleDirEvent s LEFT
handleEvent s (VtyEvent (V.EvKey V.KUp [])) = handleDirEvent s UP
handleEvent s (VtyEvent (V.EvKey V.KDown [])) = handleDirEvent s DOWN
handleEvent s _ = continue s

handleDirEvent :: AppState -> Snake.Direction -> EventM Name (Next AppState)
handleDirEvent s dir = do
  let smap = sMap s
      newSnake = moveSnake $ setSnakeDirection dir $ mSnake smap
      newState = smap {mSnake = newSnake}
  continue s {sMap = newState}

theMap :: AttrMap
theMap = attrMap V.defAttr []

app :: App AppState Tick Name
app =
  App
    { appDraw = drawUI,
      appChooseCursor = neverShowCursor,
      appHandleEvent = handleEvent,
      appStartEvent = return,
      appAttrMap = const theMap
    }

main :: IO ()
main = do
  chan <- newBChan 10
  let initialState = AppState mkMap
      buildVty = V.mkVty V.defaultConfig
  initialVty <- buildVty
  void . forkIO . forever $ do
    writeBChan chan Tick
    threadDelay 1000000
  void $ customMain initialVty buildVty (Just chan) app initialState
