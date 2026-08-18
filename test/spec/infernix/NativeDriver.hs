{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Pulsar.Connection (Broker (..), withNativeClient)
import Amoebius.Pulsar.Consumer qualified as Consumer
import Amoebius.Pulsar.Producer qualified as Producer
import Amoebius.Pulsar.Subscription (SubscriptionType (Exclusive))
import Amoebius.Pulsar.Topology
import Control.Monad (unless)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Infernix.Adapter.Pulsar
import System.Environment (getArgs)
import System.Timeout (timeout)

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [host, port, tenantRaw, namespaceRaw, commandRaw, nonceRaw, inputRaw] ->
      runDriver host port (Text.pack tenantRaw) (Text.pack namespaceRaw) (Text.pack commandRaw) (Text.pack nonceRaw) (Text.pack inputRaw)
    _ -> fail "usage: infernix-lift-native-driver HOST PORT TENANT NAMESPACE COMMAND_ID NONCE INPUT"

runDriver :: String -> String -> Text -> Text -> Text -> Text -> Text -> IO ()
runDriver host port tenant namespace commandValue nonceValue inputValue =
  withNativeClient (Broker host port) $ \client -> do
    let commandTopic = topicFor tenant namespace commandRoute LinuxCpu
        eventTopic = topicFor tenant namespace eventRoute LinuxCpu
        stableId = CommandId commandValue
        command = InferenceCommand tenant stableId (WorkId commandValue) (Nonce nonceValue) inputValue
        event = eventForCommand command
    commandConsumer <- Consumer.newConsumer client commandTopic "infernix-lift-command" Exclusive
    eventConsumer <- Consumer.newConsumer client eventTopic "infernix-lift-event" Exclusive
    commandProducer <- Producer.newProducer client commandTopic "infernix-lift-command-producer"
    eventProducer <- Producer.newProducer client eventTopic "infernix-lift-event-producer"
    _ <- Producer.produceAtSequence commandProducer 49 command
    _ <- Producer.produceAtSequence commandProducer 49 command
    receivedCommand <- receive commandConsumer
    unless (Consumer.receivedValue receivedCommand == command) (fail "infernix-lift-command-cbor-mismatch")
    Consumer.acknowledge commandConsumer (Consumer.receivedMessageId receivedCommand)
    duplicate <- timeout 2000000 (Consumer.receive commandConsumer)
    case duplicate of
      Nothing -> pure ()
      Just _ -> fail "infernix-lift-command-duplicate-not-collapsed"
    _ <- Producer.produceAtSequence eventProducer 50 event
    receivedEvent <- receive eventConsumer
    unless (Consumer.receivedValue receivedEvent == event) (fail "infernix-lift-event-cbor-mismatch")
    unless (eventCommandId event == stableId && eventWorkId event == WorkId commandValue && eventNonce event == Nonce nonceValue) (fail "infernix-lift-terminal-identity-mismatch")
    Consumer.acknowledge eventConsumer (Consumer.receivedMessageId receivedEvent)
    Consumer.closeConsumer commandConsumer
    Consumer.closeConsumer eventConsumer
    Producer.closeProducer commandProducer
    Producer.closeProducer eventProducer
    putStrLn "infernix-lift-native-driver: PASS (native CBOR command/event, stable command/work-id, duplicate collapsed)"
 where
  receive consumer = do
    result <- timeout 20000000 (Consumer.receive consumer)
    case result of
      Nothing -> fail "infernix-lift-native-message-timeout"
      Just (Left problem) -> fail ("infernix-lift-native-cbor:" <> show problem)
      Just (Right value) -> pure value

commandRoute :: RouteEntry
commandRoute = RouteEntry "infernix" "command" (Set.singleton LinuxCpu) Input False (Just "phase49") True

eventRoute :: RouteEntry
eventRoute = RouteEntry "infernix" "event" (Set.singleton LinuxCpu) Report False (Just "phase49") True
