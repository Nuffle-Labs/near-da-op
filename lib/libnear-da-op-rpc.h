#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

#define VERSION 1

typedef struct Client Client;

typedef uint8_t Commitment[32];

typedef uint32_t ShareVersion;

typedef struct BlobSafe {
  uint8_t namespace_version;
  uint32_t namespace_id;
  Commitment commitment;
  ShareVersion share_version;
  const uint8_t *data;
  size_t len;
} BlobSafe;

typedef struct RustSafeArray {
  const uint8_t *data;
  size_t len;
} RustSafeArray;

char *get_error(void);

const struct Client *new_client_file(const char *key_path,
                                     const char *contract,
                                     const char *network,
                                     uint8_t namespace_version,
                                     uint32_t namespace_);

const struct Client *new_client(const char *account_id,
                                const char *secret_key,
                                const char *contract,
                                const char *network,
                                uint8_t namespace_version,
                                uint32_t namespace_);

void free_client(struct Client *client);

char *submit(const struct Client *client, const struct BlobSafe *blobs, size_t len);

const struct BlobSafe *get(const struct Client *client, const uint8_t *transaction_id);

void free_blob(struct BlobSafe *blob);

struct RustSafeArray submit_batch(const struct Client *client,
                                  const char *candidate_hex,
                                  const uint8_t *tx_data,
                                  size_t tx_data_len);
