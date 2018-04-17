import Control.Concurrent (myThreadId, threadDelay)
import Control.Monad.IO.Class (liftIO)
import System.IO (stdout, hSetBuffering, BufferMode(LineBuffering))
import System.Random (randomIO)
import Streamly

main = runSerialT $ do
    liftIO $ hSetBuffering stdout LineBuffering
    x <- loop "A" `parmerge` loop "B"
    liftIO $ myThreadId >>= putStr . show
             >> putStr " "
             >> print x

    where

    loop :: String -> SerialT IO (String, Int)
    loop name = do
        liftIO $ threadDelay 1000000
        rnd <- liftIO (randomIO :: IO Int)
        return (name, rnd) `parmerge` loop name
