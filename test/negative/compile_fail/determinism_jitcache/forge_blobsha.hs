module Phase48ForgeBlobSha where

import Amoebius.Kernel.ContentAddress (BlobSha)

forged :: BlobSha
forged = BlobSha "deadbeef"
