{-# OPTIONS_GHC -fno-warn-unused-imports #-}
-- |
-- Module      : Streamly.Tutorial
-- Copyright   : (c) 2017 Harendra Kumar
--
-- License     : BSD3
-- Maintainer  : harendra.kumar@gmail.com
--
-- Streamly, short for stream concurrently, combines the essence of streaming
-- and concurrency in functional programming. You can write concurrent as well
-- as non-concurrent applications with streamly. Streaming enables writing
-- modular, composable and scalable applications with ease and concurrency
-- allows you to make them scale and perform well.
-- Streamly enables writing concurrent applications without being aware of
-- threads or synchronization. No explicit thread control is needed, where
-- applicable the concurrency rate is automatically controlled based on the
-- demand by the consumer. However, combinators are provided to fine tune the
-- concurrency control.
-- Streaming and concurrency together enable expressing reactive applications
-- conveniently. See "Streamly.Examples" for a simple SDL based FRP example.
--
-- Streamly streams are very much like the Haskell lists and most of the
-- functions that work on lists have a counterpart that works on streams.
-- However, streamly streams can be generated, consumed or combined
-- concurrently. In this tutorial we will go over the basic concepts and how to
-- use the library.  The documentation of @Streamly@ module has more details on
-- core APIs.  For more APIs for constructing, folding, filtering, mapping and
-- zipping etc. see the documentation of "Streamly.Prelude" module. For
-- examples and other ways to use the library see the module
-- "Streamly.Examples" as well.

module Streamly.Tutorial
    (
    -- * Streams
    -- $streams

    -- ** Generating Streams
    -- $generating

    -- ** Eliminating Streams
    -- $eliminating

    -- * Combining Streams
    -- $combining

    -- ** Semigroup Style
    -- $semigroup

    -- *** Serial composition ('<>')
    -- $serial

    -- *** Async composition ('<|')
    -- $parallel

    -- *** Interleaved composition ('<=>')
    -- $interleaved

    -- *** Fair Concurrent composition ('<|>')
    -- $fairParallel

    -- *** Custom composition
    -- $custom

    -- ** Monoid Style
    -- $monoid

    -- * Transforming Streams
    -- $transforming

    -- ** Monad
    -- $monad

    -- *** Serial Composition ('StreamT')
    -- $regularSerial

    -- *** Async Composition ('AsyncT')
    -- $concurrentNesting

    -- *** Interleaved Composition ('InterleavedT')
    -- $interleavedNesting

    -- *** Fair Concurrent Composition ('ParallelT')
    -- $fairlyConcurrentNesting

    -- *** Exercise
    -- $monadExercise

    -- ** Applicative
    -- $applicative

    -- ** Functor
    -- $functor

    -- * Zipping Streams
    -- $zipping

    -- ** Serial Zipping
    -- $serialzip

    -- ** Parallel Zipping
    -- $parallelzip

    -- * Summary of Compositions
    -- $compositionSummary

    -- * Concurrent Programming Examples
    -- $concurrent

    -- * Reactive Programming
    -- $reactive

    -- * State Machine Model
    -- $statemachine

    -- * Performance
    -- $performance

    -- * Interworking with Streaming Libraries
    -- $interwork

    -- * Comparison with Existing Packages
    -- $comparison
    )
where

import Streamly
import Streamly.Prelude
import Data.Semigroup
import Control.Applicative
import Control.Monad
import Control.Monad.IO.Class      (MonadIO(..))
import Control.Monad.Trans.Class   (MonadTrans (lift))

-- $streams
--
-- Streamly provides many different stream types depending on the desired
-- composition style. The simplest type is 'StreamT'. 'StreamT' is a monad
-- transformer, the type @StreamT m a@ represents a stream of values of type
-- 'a' in some underlying monad 'm'. For example, @StreamT IO Int@ is a stream
-- of 'Int' in 'IO' monad.

-- $generating
--
-- Pure values can be placed into the stream type using 'return' or 'pure'.
-- Effects in the IO monad can be lifted to the stream type using the 'liftIO'
-- combinator. In a transformer stack we can lift actions from the lower monad
-- using the 'lift' combinator. Some examples of streams with a single element:
--
-- @
--  return 1 :: 'StreamT' IO Int
-- @
-- @
--  liftIO $ putStrLn "Hello world!" :: 'StreamT' IO ()
-- @
--
-- We can combine streams using '<>' to create streams of many elements:
--
-- @
--  return 1 <> return 2 <> return 3 :: 'StreamT' IO Int
-- @
--
-- For more ways to construct or generate a stream see the module
-- "Streamly.Prelude".

-- $eliminating
--
-- 'runStreamT' runs a composed 'StreamT' computation, lowering the type into
-- the underlying monad and discarding the result stream:
--
-- @
-- import "Streamly"
--
-- main = 'runStreamT' $ liftIO $ putStrLn "Hello world!"
-- @
--
-- 'toList' runs a stream computation and collects the result stream in a list
-- in the underlying monad.  'toList' is a polymorphic function that works on
-- multiple stream types belonging to the class 'Streaming'. Therefore, before
-- you run a stream you need to tell how you want to interpret the stream by
-- using one of the stream type combinators ('serially', 'asyncly', 'parallely'
-- etc.). The combinator 'serially' is equivalent to annotating the type as @::
-- StreamT@.
--
-- @
-- import "Streamly"
--
-- main = do
--  xs \<- 'toList' $ 'serially' $ return 1 <> return 2
--  print xs
-- @
--
-- For other ways to eliminate or fold a stream see the module
-- "Streamly.Prelude".

-- $semigroup
-- Streams of the same type can be combined into a composite stream in many
-- different ways using one of the semigroup style binary composition operators
-- i.e. '<>', '<=>', '<|', '<|>', 'mplus'. These operators work on all stream
-- types ('StreamT', 'AsyncT' etc.) uniformly.
--
-- To illustrate the concurrent aspects, we will use the following @delay@
-- function to introduce a delay specified in seconds.
--
-- @
-- import "Streamly"
-- import Control.Concurrent
--
-- delay n = liftIO $ do
--  threadDelay (n * 1000000)
--  tid \<- myThreadId
--  putStrLn (show tid ++ ": Delay " ++ show n)
-- @

-- $serial
--
-- We have already seen, the '<>' operator. It composes two streams in series
-- i.e. the first stream is completely exhausted and then the second stream is
-- processed.  The following example prints the sequence 3, 2, 1 and takes a
-- total of 6 seconds because everything is serial:
--
-- @
-- main = 'runStreamT' $ delay 3 <> delay 2 <> delay 1
-- @
-- @
-- ThreadId 36: Delay 3
-- ThreadId 36: Delay 2
-- ThreadId 36: Delay 1
-- @

-- $interleaved
-- The '<=>' operator is serial like '<>' but it interleaves the two streams
-- i.e. it yields one element from the first stream and then one element from
-- the second stream, and so on.  The following example prints the sequence 1,
-- 3, 2, 4 and takes a total of 10 seconds because everything is serial:
--
-- @
-- main = 'runStreamT' $ (delay 1 <> delay 2) '<=>' (delay 3 <> delay 4)
-- @
-- @
-- ThreadId 36: Delay 1
-- ThreadId 36: Delay 3
-- ThreadId 36: Delay 2
-- ThreadId 36: Delay 4
-- @
--
-- Note that this operator cannot be used to fold infinite containers since it
-- requires preserving the state until a stream is finished.

-- $parallel
--
-- The '<|' operator can run both computations concurrently, /when needed/.
-- In the following example since the first computation blocks we start the
-- next one in a separate thread and so on:
--
-- @
-- main = 'runStreamT' $ delay 3 '<|' delay 2 '<|' delay 1
-- @
-- @
-- ThreadId 42: Delay 1
-- ThreadId 41: Delay 2
-- ThreadId 40: Delay 3
-- @
--
-- This is the concurrent version of the '<>' operator. The computations are
-- triggered in the same order as '<>' except that they are concurrent.  When
-- we have a tree of computations composed using this operator, the tree is
-- traversed in DFS style just like '<>'.
--
-- @
-- main = 'runStreamT' $ (p 1 '<|' p 2) '<|' (p 3 '<|' p 4)
--  where p = liftIO . print
-- @
-- @
-- 1
-- 2
-- 3
-- 4
-- @
--
-- Concurrency provided by this operator is demand driven. The second
-- computation is run concurrently with the first only if the first computation
-- is not producing enough output to keep the stream consumer busy otherwise
-- the second computation is run serially after the previous one. The number of
-- concurrent threads is adapted dynamically based on the pull rate of the
-- consumer of the stream.
-- As you can see, in the following example the computations are run in a
-- single thread one after another, because none of them blocks. However, if
-- the thread consuming the stream were faster than the producer then it would
-- have started parallel threads for each computation to keep up even if none
-- of them blocks:
--
-- @
-- main = 'runStreamT' $ traced (sqrt 9) '<|' traced (sqrt 16) '<|' traced (sqrt 25)
-- @
-- @
-- ThreadId 40
-- ThreadId 40
-- ThreadId 40
-- @
--
-- Since the concurrency provided by this operator is demand driven it cannot
-- be used when the composed computations have timers that are relative to each
-- other because all computations may not be started at the same time and
-- therefore timers in all of them may not start at the same time.  When
-- relative timing among all computations is important or when we need to start
-- all computations at once for some reason '<|>' must be used instead.
-- However, '<|' is useful in situations when we want to optimally utilize the
-- resources and we know that the computations can run in parallel but we do
-- not care if they actually run in parallel or not, that decision is left to
-- the scheduler. Also, note that this operator can be used to fold infinite
-- containers in contrast to '<|>', because it does not require us to run all
-- of them at the same time.
--
-- The left bias (or the DFS style) of the operator '<|' is suggested by its
-- shape.  You can also think of this as an unbalanced version of the fairly
-- parallel operator '<|>'.

-- $fairParallel
--
-- The 'Alternative' composition operator '<|>', like '<|', runs the composed
-- computations concurrently. However, unlike '<|' it runs all of the
-- computations in fairly parallel manner using a round robin scheduling
-- mechanism. This can be considered as the concurrent version of the fairly
-- interleaved serial operation '<=>'. Note that this cannot be used on
-- infinite containers, as it will lead to an infinite sized scheduling queue.
--
-- The following example sends a query to three search engines in parallel and
-- prints the name of the search engine as a response arrives:
--
-- @
-- import "Streamly"
-- import Network.HTTP.Simple
--
-- main = 'runStreamT' $ google \<|> bing \<|> duckduckgo
--     where
--         google     = get "https://www.google.com/search?q=haskell"
--         bing       = get "https://www.bing.com/search?q=haskell"
--         duckduckgo = get "https://www.duckduckgo.com/?q=haskell"
--         get s = liftIO (httpNoBody (parseRequest_ s) >> putStrLn (show s))
-- @

-- $custom
--
-- The 'async' API can be used to create references to asynchronously running
-- stream computations. We can then use 'uncons' to explore the streams
-- arbitrarily and then recompose individual elements to create a new stream.
-- This way we can dynamically decide which stream to explore at any given
-- time.  Take an example of a merge sort of two sorted streams. We need to
-- keep consuming items from the stream which has the lowest item in the sort
-- order.  This can be achieved using async references to streams. See
-- "Streamly.Examples.MergeSortedStreams".

-- $monoid
--
-- Each of the semigroup compositions described has an identity that can be
-- used to fold a possibly empty container. An empty stream is represented by
-- 'nil' which can be represented in various standard forms as 'mempty',
-- 'empty' or 'mzero'.
-- Some fold utilities are also provided by the library for convenience:
--
-- * 'foldWith' folds a 'Foldable' container of stream computations using the
-- given composition operator.
-- * 'foldMapWith' folds like foldWith but also maps a function before folding.
-- * 'forEachWith' is like foldMapwith but the container argument comes before
-- the function argument.
-- * The 'each' primitive from "Streamly.Prelude" folds a 'Foldable' container
-- using the '<>' operator:
--
-- All of the following are equivalent:
--
-- @
-- import "Streamly"
--
-- main = do
--  'toList' . 'serially' $ 'foldWith'    (<>) (map return [1..10]) >>= print
--  'toList' . 'serially' $ 'foldMapWith' (<>) return [1..10]       >>= print
--  'toList' . 'serially' $ 'forEachWith' (<>) [1..10] return       >>= print
--  'toList' . 'serially' $ 'each' [1..10]                          >>= print
-- @

-- $transforming
--
-- The previous section discussed ways to merge the elements of two streams
-- without doing any transformation on them. In this section we will explore
-- how to transform streams using 'Functor', 'Applicative' or 'Monad' style
-- compositions. The applicative and monad composition of all 'Streaming' types
-- behave exactly the same way as a list transformer.  For simplicity of
-- illustration we are using streams of pure values in the following examples.
-- However, the real application of streams arises when these streams are
-- generated using monadic actions.

-- $monad
--
-- In functional programmer's parlance the 'Monad' instance of 'Streaming'
-- types implement non-determinism, exploring all possible combination of
-- choices from both the streams. From an imperative programmer's point of view
-- it behaves like nested loops i.e.  for each element in the first stream and
-- for each element in the second stream apply the body of the loop. If you are
-- familiar with list transformer this behavior is exactly the same as that of
-- a list transformer.
--
-- Just like we saw in sum style compositions earlier, monadic composition also
-- has multiple variants each of which exactly corresponds to one of the sum
-- style composition variant.

-- $regularSerial
--
-- When we interpret the monadic composition as 'StreamT' we get a standard
-- list transformer like serial composition.
--
-- @
-- main = 'runStreamT' $ do
--     x <- 'each' [3,2,1]
--     delay x
-- @
-- @
-- ThreadId 30: Delay 3
-- ThreadId 30: Delay 2
-- ThreadId 30: Delay 1
-- @
--
-- As you can see the code after the @each@ statement is run three times, once
-- for each value of @x@. All the three iterations are serial and run in the
-- same thread one after another. When compared to imperative programming, this
-- can also be viewed as a @for@ loop with three iterations.
--
-- When multiple streams are composed using this style they nest in a DFS
-- manner i.e. nested iterations of an iteration are executed before we proceed
-- to the next iteration at higher level. This behaves just like nested @for@
-- loops in imperative programming.
--
-- @
-- main = 'runStreamT' $ do
--     x <- 'each' [1,2]
--     y <- 'each' [3,4]
--     liftIO $ putStrLn $ show (x, y)
-- @
-- @
-- (1,3)
-- (1,4)
-- (2,3)
-- (2,4)
-- @
--
-- You will also notice that this is the monadic equivalent of the sum style
-- composition using '<>'.

-- $concurrentNesting
--
-- When we interpret the monadic composition as 'AsyncT' we get a /concurrent/
-- list-transformer like composition. Multiple monadic continuations (or loop
-- iterations) may be started concurrently. Concurrency is demand driven
-- i.e. more concurrent iterations are started only if the previous iterations
-- are not able to produce enough output for the consumer of the output stream.
-- This is the concurrent version of 'StreamT'.
--
-- @
-- main = 'runAsyncT' $ do
--     x <- 'each' [3,2,1]
--     delay x
-- @
-- @
-- ThreadId 40: Delay 1
-- ThreadId 39: Delay 2
-- ThreadId 38: Delay 3
-- @
--
-- As you can see the code after the @each@ statement is run three times, once
-- for each value of @x@. All the three iterations are concurrent and run in
-- different threads. The iteration with least delay finishes first. When
-- compared to imperative programming, this can be viewed as a @for@ loop
-- with three concurrent iterations.
--
-- Concurrency is demand driven just as in the case of '<|'. When multiple
-- streams are composed using this style the iterations are triggered in a DFS
-- manner just like 'StreamT' i.e. nested iterations are executed before we
-- proceed to the next iteration at higher level. However, unlike 'StreamT'
-- more than one iterations may be started concurrently, and based on the
-- demand from the consumer.
--
-- @
-- main = 'runAsyncT' $ do
--     x <- 'each' [1,2]
--     y <- 'each' [3,4]
--     liftIO $ putStrLn $ show (x, y)
-- @
-- @
-- (1,3)
-- (1,4)
-- (2,3)
-- (2,4)
-- @
--
-- You will notice that this is the monadic equivalent of the '<|' style
-- sum composition. The same caveats apply to this as the '<|' operation.

-- $interleavedNesting
--
-- When we interpret the monadic composition as 'InterleavedT' we get a serial
-- but fairly interleaved list-transformer like composition. The monadic
-- continuations or iterations of the outer loop are fairly interleaved with
-- the continuations or iterations of the inner loop.
--
-- @
-- main = 'runInterleavedT' $ do
--     x <- 'each' [1,2]
--     y <- 'each' [3,4]
--     liftIO $ putStrLn $ show (x, y)
-- @
-- @
-- (1,3)
-- (2,3)
-- (1,4)
-- (2,4)
-- @
--
-- You will notice that this is the monadic equivalent of the '<=>' style
-- sum composition. The same caveats apply to this as the '<=>' operation.

-- $fairlyConcurrentNesting
--
-- When we interpret the monadic composition as 'ParallelT' we get a
-- /concurrent/ list-transformer like composition just like 'AsyncT'. The
-- difference is that this is fully parallel with all iterations starting
-- concurrently instead of the demand driven concurrency of 'AsyncT'.
--
-- @
-- main = 'runParallelT' $ do
--     x <- 'each' [3,2,1]
--     delay x
-- @
-- @
-- ThreadId 40: Delay 1
-- ThreadId 39: Delay 2
-- ThreadId 38: Delay 3
-- @
--
-- You will notice that this is the monadic equivalent of the '<|>' style
-- sum composition. The same caveats apply to this as the '<|>' operation.

-- $monadExercise
--
-- The streamly code is usually written in a way that is agnostic of the
-- specific monadic composition type. We use a polymorphic type with a
-- 'Streaming' type class constraint. When running the stream we can choose the
-- specific mode of composition. For example look at the following code.
--
-- @
-- import "Streamly"
--
-- composed :: 'Streaming' t => t m a
-- composed = do
--     sz <- sizes
--     cl <- colors
--     sh <- shapes
--     liftIO $ putStrLn $ show (sz, cl, sh)
--
--     where
--
--     sizes  = 'each' [1, 2, 3]
--     colors = 'each' ["red", "green", "blue"]
--     shapes = 'each' ["triangle", "square", "circle"]
-- @
--
-- Now we can interpret this in whatever way we want:
--
-- @
-- main = 'runStreamT'      composed
-- main = 'runAsyncT'       composed
-- main = 'runInterleavedT' composed
-- main = 'runParallelT'    composed
-- @
--
-- Equivalently, we can also write it using the type adapter combinators, like
-- this:
--
-- @
-- main = 'runStreaming' $ 'serially'     $ composed
-- main = 'runStreaming' $ 'asyncly'      $ composed
-- main = 'runStreaming' $ 'interleaving' $ composed
-- main = 'runStreaming' $ 'parallely'    $ composed
-- @
--
--  As an exercise try to figure out the output of this code for each mode of
--  composition.

-- $functor
--
-- 'fmap' transforms a stream by mapping a function on all elements of the
-- stream. The functor instance of each stream type defines 'fmap' to be
-- precisely the same as 'liftM', and therefore 'fmap' is always serial
-- irrespective of the type. For concurrent mapping, alternative versions of
-- 'fmap', namely, 'asyncMap' and 'parMap' are provided.
--
-- @
-- import "Streamly"
--
-- main = ('toList' $ 'serially' $ fmap show $ 'each' [1..10]) >>= print
-- @
--
-- Also see the 'mapM' and 'sequence' functions for mapping actions, in the
-- "Streamly.Prelude" module.

-- $applicative
--
-- Applicative is precisely the same as the 'ap' operation of 'Monad'. For
-- zipping and parallel applicatives separate types 'ZipStream' and 'ZipAsync'
-- are provided.
--
-- The following example runs all iterations serially and takes a total 17
-- seconds (1 + 3 + 4 + 2 + 3 + 4):
--
-- @
-- import "Streamly"
-- import "Streamly.Prelude"
-- import Control.Concurrent
--
-- s1 = d 1 <> d 2
-- s2 = d 3 <> d 4
-- d n = delay n >> return n
--
-- main = ('toList' . 'serially' $ (,) \<$> s1 \<*> s2) >>= print
-- @
-- @
-- ThreadId 36: Delay 1
-- ThreadId 36: Delay 3
-- ThreadId 36: Delay 4
-- ThreadId 36: Delay 2
-- ThreadId 36: Delay 3
-- ThreadId 36: Delay 4
-- [(1,3),(1,4),(2,3),(2,4)]
-- @
--
-- Similalrly interleaving runs the iterations in an interleaved order but
-- since it is serial it takes a total of 17 seconds:
--
-- @
-- main = ('toList' . 'interleaving' $ (,) \<$> s1 \<*> s2) >>= print
-- @
-- @
-- ThreadId 36: Delay 1
-- ThreadId 36: Delay 3
-- ThreadId 36: Delay 2
-- ThreadId 36: Delay 3
-- ThreadId 36: Delay 4
-- ThreadId 36: Delay 4
-- [(1,3),(2,3),(1,4),(2,4)]
-- @
--
-- 'AsyncT' can run the iterations concurrently and therefore takes a total
-- of 10 seconds (1 + 2 + 3 + 4):
--
-- @
-- main = ('toList' . 'asyncly' $ (,) \<$> s1 \<*> s2) >>= print
-- @
-- @
-- ThreadId 34: Delay 1
-- ThreadId 36: Delay 2
-- ThreadId 35: Delay 3
-- ThreadId 36: Delay 3
-- ThreadId 35: Delay 4
-- ThreadId 36: Delay 4
-- [(1,3),(2,3),(1,4),(2,4)]
-- @
--
-- Similalrly 'ParallelT' as well can run the iterations concurrently and
-- therefore takes a total of 10 seconds (1 + 2 + 3 + 4):
--
-- @
-- main = ('toList' . 'parallely' $ (,) \<$> s1 \<*> s2) >>= print
-- @
-- @
-- ThreadId 34: Delay 1
-- ThreadId 36: Delay 2
-- ThreadId 35: Delay 3
-- ThreadId 36: Delay 3
-- ThreadId 35: Delay 4
-- ThreadId 36: Delay 4
-- [(1,3),(2,3),(1,4),(2,4)]
-- @

-- $compositionSummary
--
-- The following table summarizes the types for monadic compositions and the
-- operators for sum style compositions. This table captures the essence of
-- streamly.
--
-- @
-- +-----+--------------+------------+
-- |     | Serial       | Concurrent |
-- +=====+==============+============+
-- | DFS | 'StreamT'      | 'AsyncT'     |
-- |     +--------------+------------+
-- |     | '<>'           | '<|'         |
-- +-----+--------------+------------+
-- | BFS | 'InterleavedT' | 'ParallelT'  |
-- |     +--------------+------------+
-- |     | '<=>'          | '<|>'        |
-- +-----+--------------+------------+
-- @

-- $zipping
--
-- Zipping is a special transformation where the corresponding elements of two
-- streams are combined together using a zip function producing a new stream of
-- outputs. Two different types are provided for serial and concurrent zipping.
-- These types provide an applicative instance that zips the argument streams.
-- Also see the zipping function in the "Streamly.Prelude" module.

-- $serialzip
--
-- 'ZipStream' zips streams serially:
--
-- @
-- import "Streamly"
-- import "Streamly.Prelude"
-- import Control.Concurrent
--
-- d n = delay n >> return n
-- s1 = 'adapt' . 'serially' $ d 1 <> d 2
-- s2 = 'adapt' . 'serially' $ d 3 <> d 4
--
-- main = ('toList' . 'zipping' $ (,) \<$> s1 \<*> s2) >>= print
-- @
--
-- This takes total 10 seconds to zip, which is (1 + 2 + 3 + 4) since
-- everything runs serially:
--
-- @
-- ThreadId 29: Delay 1
-- ThreadId 29: Delay 3
-- ThreadId 29: Delay 2
-- ThreadId 29: Delay 4
-- [(1,3),(2,4)]
-- @

-- $parallelzip
--
-- 'ZipAsync' zips streams concurrently:
--
-- @
-- import "Streamly"
-- import "Streamly.Prelude"
-- import Control.Concurrent
-- import System.IO (stdout, hSetBuffering, BufferMode(LineBuffering))
--
-- d n = delay n >> return n
-- s1 = 'adapt' . 'serially' $ d 1 <> d 2
-- s2 = 'adapt' . 'serially' $ d 3 <> d 4
--
-- main = do
--     liftIO $ hSetBuffering stdout LineBuffering
--     ('toList' . 'zippingAsync' $ (,) \<$> s1 \<*> s2) >>= print
-- @
--
-- This takes 7 seconds to zip, which is max (1,3) + max (2,4) because 1 and 3
-- are produced concurrently, and 2 and 4 are produced concurrently:
--
-- @
-- ThreadId 32: Delay 1
-- ThreadId 32: Delay 2
-- ThreadId 33: Delay 3
-- ThreadId 33: Delay 4
-- [(1,3),(2,4)]
-- @

-- $concurrent
--
-- There are two ways to achieve concurrency. We can generate individual
-- elements of a stream concurrently by folding with parallel composition
-- operators i.e.  '<|' or '<|>'. 'forEachWith' can be useful in such cases.
--
-- In the following example, we square each number concurrently but then
-- sum and print them serially:
--
-- @
-- import "Streamly"
-- import "Streamly.Prelude" (toList)
-- import Data.List (sum)
--
-- main = do
--     squares \<- 'toList' $ 'serially' $ 'forEachWith' ('<|') [1..100] $ \\x -\> return $ x * x
--     print $ sum squares
-- @
--
-- The following example not just computes the squares concurrently but also
-- computes the square root of their sums concurrently by using the parallel
-- monadic bind.
--
-- @
-- import "Streamly"
-- import "Streamly.Prelude" (toList)
-- import Data.List (sum)
--
-- main = do
--     z \<- 'toList' $ 'asyncly' $ do
--         xsq \<- 'forEachWith' ('<|') [1..100] $ \\x -> return $ x * x
--         ysq \<- 'forEachWith' ('<|') [1..100] $ \\x -> return $ x * x
--         return $ sqrt (xsq + ysq)
--     print $ sum z
-- @

-- $reactive
--
-- Let us see a reactive programming example:
--
-- @
-- {-\# LANGUAGE FlexibleContexts #-}
--
-- import "Streamly"
-- import Control.Concurrent (threadDelay)
-- import Control.Monad (when)
-- import Control.Monad.State
-- import Data.Semigroup (cycle1)
--
-- data Event = Harm Int | Heal Int | Quit deriving (Show)
--
-- userAction :: MonadIO m => 'StreamT' m Event
-- userAction = cycle1 $ liftIO askUser
--     where
--     askUser = do
--         command <- getLine
--         case command of
--             "potion" -> return (Heal 10)
--             "quit"   -> return  Quit
--             _        -> putStrLn "What?" >> askUser
--
-- acidRain :: MonadIO m => 'StreamT' m Event
-- acidRain = cycle1 $ liftIO (threadDelay 1000000) >> return (Harm 1)
--
-- game :: ('MonadAsync' m, MonadState Int m) => 'StreamT' m ()
-- game = do
--     event \<- userAction \<|> acidRain
--     case event of
--         Harm n -> modify $ \\h -> h - n
--         Heal n -> modify $ \\h -> h + n
--         Quit   -> fail "quit"
--
--     h <- get
--     when (h <= 0) $ fail "You die!"
--     liftIO $ putStrLn $ "Health = " ++ show h
--
-- main = do
--     putStrLn "Your health is deteriorating due to acid rain,\\
--              \\ type \\"potion\\" or \\"quit\\""
--     _ <- runStateT ('runStreamT' game) 60
--     return ()
-- @

-- $statemachine
-- State machine stuff

-- $comparison
--
-- Even though streamly covers all that is provided by the 'async' package or
-- most of what is provided by the 'streaming', 'pipes' or 'conduit' packages,
-- I would not say that it renders those useless. Streamly is like monad if
-- 'async' is applicative and monads and applicatives both have their use
-- cases. It can completely repalce 'async', the ZipAsync type is equivalent to
-- the functionality provided by 'async'.
--
-- pipes and conduit are like Arrows and streamly is like monad to them. You
-- would use pipes and conduit when you do not need the product style
-- composition and the implicit concurrency.