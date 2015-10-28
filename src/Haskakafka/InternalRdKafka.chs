{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE EmptyDataDecls #-}

module Haskakafka.InternalRdKafka where

import Control.Applicative
import Control.Monad
import Data.Word
import Foreign hiding (unsafePerformIO)
import Foreign.C.Error
import Foreign.C.String
import Foreign.C.Types
import Haskakafka.InternalRdKafkaEnum
import System.IO
import System.IO.Unsafe (unsafePerformIO)
import System.Posix.IO
import System.Posix.Types

#include "rdkafka.h"

type CInt64T = {#type int64_t #}
type CInt32T = {#type int32_t #}

{#pointer *FILE as CFilePtr -> CFile #} 
{#pointer *size_t as CSizePtr -> CSize #}

type Word8Ptr = Ptr Word8
type CCharBufPointer  = Ptr CChar

type RdKafkaMsgFlag = Int
rdKafkaMsgFlagFree :: RdKafkaMsgFlag
rdKafkaMsgFlagFree = 0x1
rdKafkaMsgFlagCopy :: RdKafkaMsgFlag
rdKafkaMsgFlagCopy = 0x2

-- Number of bytes allocated for an error buffer
nErrorBytes ::  Int
nErrorBytes = 1024 * 8

-- Helper functions
{#fun pure unsafe rd_kafka_version as ^
    {} -> `Int' #}

{#fun pure unsafe rd_kafka_version_str as ^
    {} -> `String' #}

{#fun pure unsafe rd_kafka_err2str as ^
    {enumToCInt `RdKafkaRespErrT'} -> `String' #}

{#fun pure unsafe rd_kafka_errno2err as ^
    {`Int'} -> `RdKafkaRespErrT' cIntToEnum #}


kafkaErrnoString :: IO (String)
kafkaErrnoString = do
    (Errno num) <- getErrno 
    return $ rdKafkaErr2str $ rdKafkaErrno2err (fromIntegral num)

-- Kafka Pointer Types
data RdKafkaConfT
{#pointer *rd_kafka_conf_t as RdKafkaConfTPtr foreign -> RdKafkaConfT #}

data RdKafkaTopicConfT
{#pointer *rd_kafka_topic_conf_t as RdKafkaTopicConfTPtr foreign -> RdKafkaTopicConfT #} 

data RdKafkaT
{#pointer *rd_kafka_t as RdKafkaTPtr foreign -> RdKafkaT #}

data RdKafkaTopicT
{#pointer *rd_kafka_topic_t as RdKafkaTopicTPtr foreign -> RdKafkaTopicT #}

data RdKafkaMessageT = RdKafkaMessageT 
    { err'RdKafkaMessageT :: RdKafkaRespErrT
    , partition'RdKafkaMessageT :: Int
    , len'RdKafkaMessageT :: Int
    , keyLen'RdKafkaMessageT :: Int
    , offset'RdKafkaMessageT :: Int64
    , payload'RdKafkaMessageT :: Word8Ptr
    , key'RdKafkaMessageT :: Word8Ptr
    }
    deriving (Show, Eq)
    
instance Storable RdKafkaMessageT where
    alignment _ = {#alignof rd_kafka_message_t#}
    sizeOf _ = {#sizeof rd_kafka_message_t#}
    peek p = RdKafkaMessageT
        <$> liftM cIntToEnum  ({#get rd_kafka_message_t->err #} p)
        <*> liftM fromIntegral ({#get rd_kafka_message_t->partition #} p)
        <*> liftM fromIntegral ({#get rd_kafka_message_t->len #} p)
        <*> liftM fromIntegral ({#get rd_kafka_message_t->key_len#} p)
        <*> liftM fromIntegral ({#get rd_kafka_message_t->offset#} p)
        <*> liftM castPtr ({#get rd_kafka_message_t->payload#} p)
        <*> liftM castPtr ({#get rd_kafka_message_t->key#} p)
    poke p x = do
      {#set rd_kafka_message_t.err#} p (enumToCInt $ err'RdKafkaMessageT x)
      {#set rd_kafka_message_t.partition#} p (fromIntegral $ partition'RdKafkaMessageT x)
      {#set rd_kafka_message_t.len#} p (fromIntegral $ len'RdKafkaMessageT x)
      {#set rd_kafka_message_t.key_len#} p (fromIntegral $ keyLen'RdKafkaMessageT x)
      {#set rd_kafka_message_t.offset#} p (fromIntegral $ offset'RdKafkaMessageT x)
      {#set rd_kafka_message_t.payload#} p (castPtr $ payload'RdKafkaMessageT x)
      {#set rd_kafka_message_t.key#} p (castPtr $ key'RdKafkaMessageT x)

{#pointer *rd_kafka_message_t as RdKafkaMessageTPtr foreign -> RdKafkaMessageT #}

data RdKafkaMetadataBrokerT = RdKafkaMetadataBrokerT
  { id'RdKafkaMetadataBrokerT  :: Int
  , host'RdKafkaMetadataBrokerT :: CString
  , port'RdKafkaMetadataBrokerT :: Int
  } deriving (Show, Eq)

{#pointer *rd_kafka_metadata_broker_t as RdKafkaMetadataBrokerTPtr -> RdKafkaMetadataBrokerT #}


instance Storable RdKafkaMetadataBrokerT where
  alignment _ = {#alignof rd_kafka_metadata_broker_t#}
  sizeOf _ = {#sizeof rd_kafka_metadata_broker_t#}
  peek p = RdKafkaMetadataBrokerT
    <$> liftM fromIntegral ({#get rd_kafka_metadata_broker_t->id #} p)
    <*> liftM id ({#get rd_kafka_metadata_broker_t->host #} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_broker_t->port #} p)
  poke = undefined

data RdKafkaMetadataPartitionT = RdKafkaMetadataPartitionT
  { id'RdKafkaMetadataPartitionT :: Int
  , err'RdKafkaMetadataPartitionT :: RdKafkaRespErrT
  , leader'RdKafkaMetadataPartitionT :: Int
  , replicaCnt'RdKafkaMetadataPartitionT :: Int
  , replicas'RdKafkaMetadataPartitionT :: Ptr CInt32T
  , isrCnt'RdKafkaMetadataPartitionT :: Int
  , isrs'RdKafkaMetadataPartitionT :: Ptr CInt32T
  } deriving (Show, Eq)

instance Storable RdKafkaMetadataPartitionT where
  alignment _ = {#alignof rd_kafka_metadata_partition_t#}
  sizeOf _ = {#sizeof rd_kafka_metadata_partition_t#}
  peek p = RdKafkaMetadataPartitionT
    <$> liftM fromIntegral ({#get rd_kafka_metadata_partition_t->id#} p)
    <*> liftM cIntToEnum ({#get rd_kafka_metadata_partition_t->err#} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_partition_t->leader#} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_partition_t->replica_cnt#} p)
    <*> liftM castPtr ({#get rd_kafka_metadata_partition_t->replicas#} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_partition_t->isr_cnt#} p)
    <*> liftM castPtr ({#get rd_kafka_metadata_partition_t->isrs#} p)

  poke = undefined

{#pointer *rd_kafka_metadata_partition_t as RdKafkaMetadataPartitionTPtr -> RdKafkaMetadataPartitionT #}

data RdKafkaMetadataTopicT = RdKafkaMetadataTopicT
  { topic'RdKafkaMetadataTopicT :: CString
  , partitionCnt'RdKafkaMetadataTopicT :: Int
  , partitions'RdKafkaMetadataTopicT :: Ptr RdKafkaMetadataPartitionT
  , err'RdKafkaMetadataTopicT :: RdKafkaRespErrT
  } deriving (Show, Eq)

instance Storable RdKafkaMetadataTopicT where
  alignment _ = {#alignof rd_kafka_metadata_topic_t#}
  sizeOf _ = {#sizeof rd_kafka_metadata_topic_t #}
  peek p = RdKafkaMetadataTopicT
    <$> liftM id ({#get rd_kafka_metadata_topic_t->topic #} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_topic_t->partition_cnt #} p)
    <*> liftM castPtr ({#get rd_kafka_metadata_topic_t->partitions #} p)
    <*> liftM cIntToEnum ({#get rd_kafka_metadata_topic_t->err #} p)
  poke _ _ = undefined

{#pointer *rd_kafka_metadata_topic_t as RdKafkaMetadataTopicTPtr -> RdKafkaMetadataTopicT #}

data RdKafkaMetadataT = RdKafkaMetadataT
  { brokerCnt'RdKafkaMetadataT :: Int
  , brokers'RdKafkaMetadataT :: RdKafkaMetadataBrokerTPtr
  , topicCnt'RdKafkaMetadataT :: Int
  , topics'RdKafkaMetadataT :: RdKafkaMetadataTopicTPtr
  , origBrokerId'RdKafkaMetadataT :: CInt32T
  } deriving (Show, Eq)

instance Storable RdKafkaMetadataT where
  alignment _ = {#alignof rd_kafka_metadata_t#}
  sizeOf _ = {#sizeof rd_kafka_metadata_t#}
  peek p = RdKafkaMetadataT
    <$> liftM fromIntegral ({#get rd_kafka_metadata_t->broker_cnt #} p)
    <*> liftM castPtr ({#get rd_kafka_metadata_t->brokers #} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_t->topic_cnt #} p)
    <*> liftM castPtr ({#get rd_kafka_metadata_t->topics #} p)
    <*> liftM fromIntegral ({#get rd_kafka_metadata_t->orig_broker_id #} p)
  poke _ _ = undefined

{#pointer *rd_kafka_metadata_t as RdKafkaMetadataTPtr foreign -> RdKafkaMetadataT #}

-- rd_kafka_message
foreign import ccall unsafe "rdkafka.h &rd_kafka_message_destroy"
    rdKafkaMessageDestroy :: FunPtr (Ptr RdKafkaMessageT -> IO ())

-- rd_kafka_conf
{#fun unsafe rd_kafka_conf_new as ^
    {} -> `RdKafkaConfTPtr' #}

foreign import ccall unsafe "rdkafka.h &rd_kafka_conf_destroy"
    rdKafkaConfDestroy :: FunPtr (Ptr RdKafkaConfT -> IO ())

{#fun unsafe rd_kafka_conf_dup as ^
    {`RdKafkaConfTPtr'} -> `RdKafkaConfTPtr' #}

{#fun unsafe rd_kafka_conf_set as ^
  {`RdKafkaConfTPtr', `String', `String', id `CCharBufPointer', cIntConv `CSize'} 
  -> `RdKafkaConfResT' cIntToEnum #}

newRdKafkaConfT :: IO RdKafkaConfTPtr
newRdKafkaConfT = do
    ret <- rdKafkaConfNew
    addForeignPtrFinalizer rdKafkaConfDestroy ret
    return ret

{#fun unsafe rd_kafka_conf_dump as ^
    {`RdKafkaConfTPtr', castPtr `CSizePtr'} -> `Ptr CString' id #}

{#fun unsafe rd_kafka_conf_dump_free as ^
    {id `Ptr CString', cIntConv `CSize'} -> `()' #}

{#fun unsafe rd_kafka_conf_properties_show as ^
    {`CFilePtr'} -> `()' #}

-- rd_kafka_topic_conf
{#fun unsafe rd_kafka_topic_conf_new as ^
    {} -> `RdKafkaTopicConfTPtr' #}
{#fun unsafe rd_kafka_topic_conf_dup as ^
    {`RdKafkaTopicConfTPtr'} -> `RdKafkaTopicConfTPtr' #}

foreign import ccall unsafe "rdkafka.h &rd_kafka_topic_conf_destroy"
    rdKafkaTopicConfDestroy :: FunPtr (Ptr RdKafkaTopicConfT -> IO ())

{#fun unsafe rd_kafka_topic_conf_set as ^
  {`RdKafkaTopicConfTPtr', `String', `String', id `CCharBufPointer', cIntConv `CSize'} 
  -> `RdKafkaConfResT' cIntToEnum #}

newRdKafkaTopicConfT :: IO RdKafkaTopicConfTPtr
newRdKafkaTopicConfT = do
    ret <- rdKafkaTopicConfNew
    addForeignPtrFinalizer rdKafkaTopicConfDestroy ret
    return ret

{#fun unsafe rd_kafka_topic_conf_dump as ^
    {`RdKafkaTopicConfTPtr', castPtr `CSizePtr'} -> `Ptr CString' id #}

-- rd_kafka
{#fun unsafe rd_kafka_new as ^
    {enumToCInt `RdKafkaTypeT', `RdKafkaConfTPtr', id `CCharBufPointer', cIntConv `CSize'} 
    -> `RdKafkaTPtr' #}

foreign import ccall unsafe "rdkafka.h &rd_kafka_destroy"
    rdKafkaDestroy :: FunPtr (Ptr RdKafkaT -> IO ())

newRdKafkaT :: RdKafkaTypeT -> RdKafkaConfTPtr -> IO (Either String RdKafkaTPtr)
newRdKafkaT kafkaType confPtr = 
    allocaBytes nErrorBytes $ \charPtr -> do
        duper <- rdKafkaConfDup confPtr
        ret <- rdKafkaNew kafkaType duper charPtr (fromIntegral nErrorBytes)
        withForeignPtr ret $ \realPtr -> do
            if realPtr == nullPtr then peekCString charPtr >>= return . Left
            else do
                addForeignPtrFinalizer rdKafkaDestroy ret
                return $ Right ret

{#fun unsafe rd_kafka_brokers_add as ^
    {`RdKafkaTPtr', `String'} -> `Int' #}

{#fun unsafe rd_kafka_set_log_level as ^
  {`RdKafkaTPtr', `Int'} -> `()' #}

-- rd_kafka consume

{#fun unsafe rd_kafka_consume_start as rdKafkaConsumeStartInternal
    {`RdKafkaTopicTPtr', cIntConv `CInt32T', cIntConv `CInt64T'} -> `Int' #}

rdKafkaConsumeStart :: RdKafkaTopicTPtr -> Int -> Int64 -> IO (Maybe String)
rdKafkaConsumeStart topicPtr partition offset = do
    i <- rdKafkaConsumeStartInternal topicPtr (fromIntegral partition) (fromIntegral offset)
    case i of 
        -1 -> kafkaErrnoString >>= return . Just
        _ -> return Nothing
{#fun unsafe rd_kafka_consume_stop as rdKafkaConsumeStopInternal
    {`RdKafkaTopicTPtr', cIntConv `CInt32T'} -> `Int' #}

{#fun rd_kafka_consume as ^
  {`RdKafkaTopicTPtr', cIntConv `CInt32T', `Int'} -> `RdKafkaMessageTPtr' #}

{#fun rd_kafka_consume_batch as ^
  {`RdKafkaTopicTPtr', cIntConv `CInt32T', `Int', castPtr `Ptr (Ptr RdKafkaMessageT)', cIntConv `CSize'}
  -> `CSize' cIntConv #}

rdKafkaConsumeStop :: RdKafkaTopicTPtr -> Int -> IO (Maybe String)
rdKafkaConsumeStop topicPtr partition = do
    i <- rdKafkaConsumeStopInternal topicPtr (fromIntegral partition)
    case i of 
        -1 -> kafkaErrnoString >>= return . Just
        _ -> return Nothing

{#fun unsafe rd_kafka_offset_store as rdKafkaOffsetStore
  {`RdKafkaTopicTPtr', cIntConv `CInt32T', cIntConv `CInt64T'} 
  -> `RdKafkaRespErrT' cIntToEnum #}

-- rd_kafka produce

{#fun unsafe rd_kafka_produce as ^
    {`RdKafkaTopicTPtr', cIntConv `CInt32T', `Int', castPtr `Word8Ptr', 
     cIntConv `CSize', castPtr `Word8Ptr', cIntConv `CSize', castPtr `Word8Ptr'}
     -> `Int' #}

{#fun unsafe rd_kafka_produce_batch as ^
    {`RdKafkaTopicTPtr', cIntConv `CInt32T', `Int', `RdKafkaMessageTPtr', `Int'} -> `Int' #}

castMetadata :: Ptr (Ptr RdKafkaMetadataT) -> Ptr (Ptr ())
castMetadata ptr = castPtr ptr

-- rd_kafka_metadata

{#fun unsafe rd_kafka_metadata as ^
   {`RdKafkaTPtr', boolToCInt `Bool', `RdKafkaTopicTPtr', 
    castMetadata `Ptr (Ptr RdKafkaMetadataT)', `Int'}
   -> `RdKafkaRespErrT' cIntToEnum #}

{# fun unsafe rd_kafka_metadata_destroy as ^
   {castPtr `Ptr RdKafkaMetadataT'} -> `()' #}

{#fun unsafe rd_kafka_poll as ^
    {`RdKafkaTPtr', `Int'} -> `Int' #}

{#fun unsafe rd_kafka_outq_len as ^
    {`RdKafkaTPtr'} -> `Int' #}

{#fun unsafe rd_kafka_dump as ^
    {`CFilePtr', `RdKafkaTPtr'} -> `()' #}


-- rd_kafka_topic
{#fun unsafe rd_kafka_topic_new as ^
    {`RdKafkaTPtr', `String', `RdKafkaTopicConfTPtr'} -> `RdKafkaTopicTPtr' #}

foreign import ccall unsafe "rdkafka.h &rd_kafka_topic_destroy"
    rdKafkaTopicDestroy :: FunPtr (Ptr RdKafkaTopicT -> IO ())

newRdKafkaTopicT :: RdKafkaTPtr -> String -> RdKafkaTopicConfTPtr -> IO (Either String RdKafkaTopicTPtr)
newRdKafkaTopicT kafkaPtr topic topicConfPtr = do
    duper <- rdKafkaTopicConfDup topicConfPtr
    ret <- rdKafkaTopicNew kafkaPtr topic duper
    withForeignPtr ret $ \realPtr ->
        if realPtr == nullPtr then kafkaErrnoString >>= return . Left
        else do
            addForeignPtrFinalizer rdKafkaTopicDestroy ret
            return $ Right ret

-- Marshall / Unmarshall
enumToCInt :: Enum a => a -> CInt
enumToCInt = fromIntegral . fromEnum
cIntToEnum :: Enum a => CInt -> a
cIntToEnum = toEnum . fromIntegral
cIntConv :: (Integral a, Num b) =>  a -> b
cIntConv = fromIntegral
boolToCInt :: Bool -> CInt
boolToCInt True = CInt 1
boolToCInt False = CInt 0

-- Handle -> File descriptor

foreign import ccall "" fdopen :: Fd -> CString -> IO (Ptr CFile)
 
handleToCFile :: Handle -> String -> IO (CFilePtr)
handleToCFile h m =
 do iomode <- newCString m
    fd <- handleToFd h
    fdopen fd iomode
 
c_stdin :: IO CFilePtr
c_stdin = handleToCFile stdin "r"
c_stdout :: IO CFilePtr
c_stdout = handleToCFile stdout "w"
c_stderr :: IO CFilePtr
c_stderr = handleToCFile stderr "w"
