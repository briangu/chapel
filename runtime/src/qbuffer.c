

#ifndef SIMPLE_TEST
#include "chplrt.h"
#endif

#include "qbuffer.h"

#include "sys.h"

#include <limits.h>
#include <sys/mman.h>

#include <assert.h>

// 64kb blocks... note tile64 page size is 64K
// this really should be a multiple of page size...
// but we can't know page size at compile time
size_t qbytes_iobuf_size = 64*1024;

// prototypes.

void qbytes_free_iobuf(qbytes_t* b);
void debug_print_bytes(qbytes_t* b);
err_t qbuffer_init_part(qbuffer_part_t* p, qbytes_t* bytes, int64_t skip_bytes, int64_t len_bytes, int64_t end_offset);

/*
extern int32_t chpl_atomic_fetch_add(int32_t* ptr, int32_t incr);

extern void* chpl_malloc(size_t number, size_t size, uint16_t description, int32_t lineno, const char* filename);
extern void* chpl_realloc(void* ptr, size_t number, size_t size, uint16_t description, int32_t lineno, const char* filename);
extern void chpl_free(void* ptr, int32_t lineno, const char* filename);

#define malloc(len) chpl_malloc(1, len, 0, 0, NULL)
#define realloc(ptr, len) chpl_realloc(ptr, 1, len, 0, 0, NULL)
#define free(ptr) chpl_free(ptr, 0, NULL);
*/

// global, shared pools.

void _qbytes_free_qbytes(qbytes_t* b)
{
  b->data = NULL;
  b->len = 0;
  b->free_function = NULL;
  DO_DESTROY_REFCNT(b);
  qio_free(b);
}

void qbytes_free_null(qbytes_t* b) {
  _qbytes_free_qbytes(b);
}

void qbytes_free_munmap(qbytes_t* b) {
  err_t err;

  /* I don't believe this is required, but 
   * I've heard here and there it might be for NFS...
   *
  rc = msync(b->data, b->len, MS_ASYNC);
  if( rc ) fprintf(stderr, "Warning - in qbytes_free_munmap, msync failed with %i, errno %i\n", rc, errno);
  */

  err = sys_munmap(b->data, b->len);
  assert( !err );

  _qbytes_free_qbytes(b);
}

void qbytes_free_free(qbytes_t* b) {
  qio_free(b->data);
  _qbytes_free_qbytes(b);
}

void qbytes_free_iobuf(qbytes_t* b) {
  // iobuf is just something to be freed with free()
  return qbytes_free_free(b);
}

void debug_print_bytes(qbytes_t* b)
{
  fprintf(stderr, "bytes %p: data=%p len=%lli ref_cnt=%li free_function=%p flags=%i\n",
          b, b->data, (long long int) b->len, (long int) DO_GET_REFCNT(b),
          b->free_function, b->flags);
}

void _qbytes_init_generic(qbytes_t* ret, void* give_data, int64_t len, qbytes_free_t free_function)
{
  ret->data = give_data;
  ret->len = len;
  DO_INIT_REFCNT(ret);
  ret->flags = 0;
  ret->free_function = free_function;
}

err_t qbytes_create_generic(qbytes_t** out, void* give_data, int64_t len, qbytes_free_t free_function)
{
  qbytes_t* ret = NULL;

  ret = qio_calloc(1, sizeof(qbytes_t));
  if( ! ret ) return ENOMEM;

  _qbytes_init_generic(ret, give_data, len, free_function);

  *out = ret;

  return 0;
}

err_t _qbytes_init_iobuf(qbytes_t* ret)
{
  void* data = NULL;
  err_t err;
  
  if( (qbytes_iobuf_size & 4095) == 0 ) {
    // multiple of 4K
    err = posix_memalign(&data, qbytes_iobuf_size, qbytes_iobuf_size);
    if( err ) return err;
    memset(data, 0, qbytes_iobuf_size);
  } else {
    data = qio_calloc(1, qbytes_iobuf_size);
    if( ! ret ) return ENOMEM;
  }

  _qbytes_init_generic(ret, data, qbytes_iobuf_size, qbytes_free_iobuf);

  return 0;
}


err_t qbytes_create_iobuf(qbytes_t** out)
{
  qbytes_t* ret = NULL;
  err_t err;

  ret = qio_calloc(1, sizeof(qbytes_t));
  if( ! ret ) return ENOMEM;

  err = _qbytes_init_iobuf(ret);
  if( err ) {
    qio_free(ret);
    *out = NULL;
    return err;
  }

  *out = ret;
  return 0;
}


err_t _qbytes_init_calloc(qbytes_t* ret, int64_t len)
{
  void* data;

  data = qio_calloc(1,len);
  if( data == NULL ) {
    return ENOMEM;
  }

  _qbytes_init_generic(ret, data, len, qbytes_free_free);

  return 0;
}

err_t qbytes_create_calloc(qbytes_t** out, int64_t len)
{
  qbytes_t* ret = NULL;
  err_t err;

  ret = qio_calloc(1, sizeof(qbytes_t));
  if( ! ret ) return ENOMEM;

  err = _qbytes_init_calloc(ret, len);
  if( err ) {
    qio_free(ret);
    *out = NULL;
    return err;
  }

  *out = ret;
  return 0;
}

/*
static inline int leadz64(uint64_t i)
{
  return __builtin_clzll(i);
}

static inline int log2lli(uint64_t i)
{
  return 63 - leadz64(i);
}

int qbytes_append_realloc(qbytes_t* qb, size_t item_size, void* item)
{
   int64_t one = 1;
   int64_t exp;
   int64_t len = qb->len;
   void* a = qb->data;

   if( item_size == 0 ) return 0;
   if( 0 == len ) exp = 0;
   else exp = one << log2lli(len);
   if( len == exp ) {
      // the array is full - double its size.
      if( exp == 0 ) exp = 1;
      while( len + item_size > exp ) exp = 2*exp; 

      a = (unsigned char*) realloc(a, exp);
      if( !a ) return ENOMEM;
      qb->data = a;
   }
   // now put the new value in.
   memcpy(a + len, item, item_size);
   qb->len += item_size; // increment the item size.

   return 0;
}
*/

static inline
void qbuffer_clear_cached(qbuffer_t* buf)
{
}

void debug_print_qbuffer_iter(qbuffer_iter_t* iter)
{
  fprintf(stderr, "offset=%lli ", (long long int) iter->offset);
  debug_print_deque_iter(& iter->iter);
}

void debug_print_qbuffer(qbuffer_t* buf)
{
  deque_iterator_t cur = deque_begin(& buf->deque);
  deque_iterator_t end = deque_end(& buf->deque);

  fprintf(stderr, "buf %p: offset_start=%lli offset_end=%lli deque:\n",
          buf, (long long int) buf->offset_start, (long long int) buf->offset_end);

  // Print out the deque iterators
  debug_print_deque_iter(&cur);
  debug_print_deque_iter(&end);

  while( ! deque_it_equals(cur, end) ) {
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr( sizeof(qbuffer_part_t), cur);
    fprintf(stderr, "part %p: bytes=%p skip=%lli len=%lli end=%lli\n", 
            qbp, qbp->bytes,
            (long long int) qbp->skip_bytes,
            (long long int) qbp->len_bytes,
            (long long int) qbp->end_offset);

    deque_it_forward_one( sizeof(qbuffer_part_t), &cur );
  }
}

err_t qbuffer_init(qbuffer_t* buf)
{
  memset(buf, 0, sizeof(qbuffer_t));
  DO_INIT_REFCNT(buf);
  return deque_init(sizeof(qbuffer_part_t), & buf->deque, 0);
}

err_t qbuffer_destroy(qbuffer_t* buf)
{
  err_t err = 0;
  deque_iterator_t cur = deque_begin(& buf->deque);
  deque_iterator_t end = deque_end(& buf->deque);

  while( ! deque_it_equals(cur, end) ) {
    qbuffer_part_t* qbp = deque_it_get_cur_ptr(sizeof(qbuffer_part_t), cur);

    // release the qbuffer.
    qbytes_release(qbp->bytes);

    deque_it_forward_one(sizeof(qbuffer_part_t), &cur);
  }

  // remove any cached data
  qbuffer_clear_cached(buf);

  // destroy the deque
  deque_destroy(& buf->deque);

  DO_DESTROY_REFCNT(buf);

  return err;
}

err_t qbuffer_create(qbuffer_t** out)
{
  qbuffer_t* ret = NULL;
  err_t err;

  ret = qio_malloc(sizeof(qbuffer_t));
  if( ! ret ) return ENOMEM;

  err = qbuffer_init(ret);
  if( err ) {
    qio_free(ret);
    return err;
  }

  *out = ret;

  return 0;
}

err_t qbuffer_destroy_free(qbuffer_t* buf)
{
  err_t err;
  err = qbuffer_destroy(buf);
  qio_free(buf);
  return err;
}

err_t qbuffer_init_part(qbuffer_part_t* p, qbytes_t* bytes, int64_t skip_bytes, int64_t len_bytes, int64_t end_offset)
{
  if( len_bytes < 0 || skip_bytes < 0 ) return EINVAL;

  if( skip_bytes + len_bytes > bytes->len ) return EINVAL;

  qbytes_retain(bytes);

  p->bytes = bytes;
  p->skip_bytes = skip_bytes;
  p->len_bytes = len_bytes;
  p->end_offset = end_offset;
  p->flags = 0;

  if( skip_bytes == 0 && len_bytes == bytes->len ) p->flags |= QB_PART_FLAGS_EXTENDABLE_TO_ENTIRE_BYTES;

  return 0;
}

void qbuffer_extend_back(qbuffer_t* buf)
{
  if( deque_size(sizeof(qbuffer_part_t), &buf->deque) > 0 ) {
    // Get the last part.
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr( sizeof(qbuffer_part_t), deque_last(sizeof(qbuffer_part_t), &buf->deque));
    if( (qbp->flags & QB_PART_FLAGS_EXTENDABLE_TO_ENTIRE_BYTES) &&
        qbp->len_bytes < qbp->bytes->len ) {
      qbp->end_offset = (qbp->end_offset - qbp->len_bytes) + qbp->bytes->len;
      qbp->len_bytes = qbp->bytes->len;
      buf->offset_end = qbp->end_offset;
    }
  }
}

void qbuffer_extend_front(qbuffer_t* buf)
{
  if( deque_size(sizeof(qbuffer_part_t), &buf->deque) > 0 ) {
    // Get the first part.
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr( sizeof(qbuffer_part_t), deque_begin(& buf->deque));
    if( (qbp->flags & QB_PART_FLAGS_EXTENDABLE_TO_ENTIRE_BYTES) &&
        qbp->skip_bytes > 0 ) {
      qbp->len_bytes = qbp->bytes->len;
      qbp->skip_bytes = 0;
      buf->offset_start = qbp->end_offset - qbp->len_bytes;
    }
  }
}

err_t qbuffer_append(qbuffer_t* buf, qbytes_t* bytes, int64_t skip_bytes, int64_t len_bytes)
{
  qbuffer_part_t part;
  int64_t new_end;
  err_t err;

  new_end = buf->offset_end + len_bytes;
  // init part retains the bytes.
  err = qbuffer_init_part(&part, bytes, skip_bytes, len_bytes, new_end);
  if( err ) return err;

  err = deque_push_back(sizeof(qbuffer_part_t), &buf->deque, &part);
  if( err ) {
    qbytes_release(bytes); // release the bytes.
    return err;
  }

  buf->offset_end = new_end;

  // invalidate cached entries.
  qbuffer_clear_cached(buf);

  return 0;
}

err_t qbuffer_append_buffer(qbuffer_t* buf, qbuffer_t* src, qbuffer_iter_t src_start, qbuffer_iter_t src_end)
{
  qbuffer_iter_t src_cur = src_start;
  qbytes_t* bytes;
  int64_t skip;
  int64_t len;
  err_t err;

  if( buf == src ) return EINVAL;

  while( qbuffer_iter_num_bytes(src_cur, src_end) > 0 ) {
    qbuffer_iter_get(src_cur, src_end, &bytes, &skip, &len);

    err = qbuffer_append(buf, bytes, skip, len);
    if( err ) return err;

    qbuffer_iter_next_part(src, &src_cur);
  }

  return 0;
}

err_t qbuffer_prepend(qbuffer_t* buf, qbytes_t* bytes, int64_t skip_bytes, int64_t len_bytes)
{
  qbuffer_part_t part;
  int64_t old_start, new_start;
  err_t err;

  old_start = buf->offset_start;
  new_start = old_start - len_bytes;

  // init part retains the bytes.
  err = qbuffer_init_part(&part, bytes, skip_bytes, len_bytes, old_start);
  if( err ) return err;

  err = deque_push_front(sizeof(qbuffer_part_t), &buf->deque, &part);
  if( err ) {
    qbytes_release(bytes); // release the bytes.
    return err;
  }

  buf->offset_start = new_start;

  // invalidate cached entries.
  qbuffer_clear_cached(buf);

  return 0;
}

void qbuffer_trim_front(qbuffer_t* buf, int64_t remove_bytes)
{
  int64_t new_start = buf->offset_start + remove_bytes;

  if( remove_bytes == 0 ) return;
  
  assert( remove_bytes > 0 );
  assert( new_start <= buf->offset_end );

  while( deque_size(sizeof(qbuffer_part_t), &buf->deque) > 0 ) {
    // Get the first part.
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr( sizeof(qbuffer_part_t), deque_begin(& buf->deque));

    if( qbp->end_offset - qbp->len_bytes < new_start ) {
      // we might remove it entirely, or maybe
      // we just adjust its length and skip.
      if( qbp->end_offset <= new_start ) {
        qbytes_t* bytes = qbp->bytes;
        // ends entirely before new_start, remove the chunk.
        // Remove it from the deque
        deque_pop_front(sizeof(qbuffer_part_t), &buf->deque);
        // release the bytes.
        qbytes_release(bytes);
      } else {
        // Keep only a part of this chunk.
        int64_t remove_here = new_start - (qbp->end_offset - qbp->len_bytes);
        qbp->skip_bytes += remove_here;
        qbp->len_bytes -= remove_here;
        break; // this is the last one.
      }
    } else {
      break; // we're past
    }
  }

  // Now set the new offset.
  buf->offset_start = new_start;

  // invalidate cached entries.
  qbuffer_clear_cached(buf);
}

void qbuffer_trim_back(qbuffer_t* buf, int64_t remove_bytes)
{
  int64_t new_end = buf->offset_end - remove_bytes;

  if( remove_bytes == 0 ) return;
  assert( remove_bytes > 0 );
  assert( new_end >= buf->offset_start );

  // Go through the deque removing entire parts.
  while( deque_size(sizeof(qbuffer_part_t), &buf->deque) > 0 ) {
    // Get the last part.
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr( sizeof(qbuffer_part_t), deque_last(sizeof(qbuffer_part_t), &buf->deque));

    if( qbp->end_offset > new_end ) {
      // we might remove it entirely, or maybe
      // we just adjust its length and skip.
      if( qbp->end_offset - qbp->len_bytes >= new_end ) {
        qbytes_t* bytes = qbp->bytes;
        // starts entirely after new_end, remove the chunk.
        // Remove it from the deque
        deque_pop_front(sizeof(qbuffer_part_t), &buf->deque);
        // release the bytes.
        qbytes_release(bytes);
      } else {
        // Keep only a part of this chunk.
        int64_t remove_here = qbp->end_offset - new_end;
        qbp->len_bytes -= remove_here;
        qbp->end_offset -= remove_here;
        break; // this is the last one.
      }
    } else {
      break; // we're past
    }
  }

  // Now set the new offset.
  buf->offset_end = new_end;

  // invalidate cached entries.
  qbuffer_clear_cached(buf);
}

err_t qbuffer_pop_front(qbuffer_t* buf)
{
  qbytes_t* bytes;
  int64_t skip;
  int64_t len;
  qbuffer_iter_t chunk;

  if ( qbuffer_num_parts(buf) == 0 ) return EINVAL;

  chunk = qbuffer_begin(buf);

  qbuffer_iter_get(chunk, qbuffer_end(buf), &bytes, &skip, &len);

  deque_pop_front(sizeof(qbuffer_part_t), &buf->deque);

  buf->offset_start += len;

  return 0;
}

err_t qbuffer_pop_back(qbuffer_t* buf)
{
  qbytes_t* bytes;
  int64_t skip;
  int64_t len;
  qbuffer_iter_t chunk;

  if ( qbuffer_num_parts(buf) == 0 ) return EINVAL;
  
  chunk = qbuffer_end(buf);
  qbuffer_iter_prev_part(buf, &chunk);

  qbuffer_iter_get(chunk, qbuffer_end(buf), &bytes, &skip, &len);

  deque_pop_back(sizeof(qbuffer_part_t), &buf->deque);

  buf->offset_end -= len;

  return 0;
}

void qbuffer_reposition(qbuffer_t* buf, int64_t new_offset_start)
{
  deque_iterator_t start = deque_begin(& buf->deque);
  deque_iterator_t end = deque_end(& buf->deque);
  deque_iterator_t iter;
  qbuffer_part_t* qbp;
  int64_t diff;

  diff = new_offset_start - buf->offset_start;
  buf->offset_start += diff;
  buf->offset_end += diff;

  iter = start;

  while( ! deque_it_equals(iter, end) ) {
    qbp = deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter);
    qbp->end_offset += diff;
  }
}

qbuffer_iter_t qbuffer_begin(qbuffer_t* buf)
{
  qbuffer_iter_t ret;
  ret.offset = buf->offset_start;
  ret.iter = deque_begin(& buf->deque);
  return ret;
}

qbuffer_iter_t qbuffer_end(qbuffer_t* buf)
{
  qbuffer_iter_t ret;
  ret.offset = buf->offset_end;
  ret.iter = deque_end( & buf->deque );
  return ret;
}

void qbuffer_iter_next_part(qbuffer_t* buf, qbuffer_iter_t* iter)
{
  deque_iterator_t d_end = deque_end( & buf->deque );

  deque_it_forward_one(sizeof(qbuffer_part_t), & iter->iter);

  if( deque_it_equals(iter->iter, d_end) ) {
    // if we're not at the end now... offset is from buf
    iter->offset = buf->offset_end;
  } else {
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
    iter->offset = qbp->end_offset - qbp->len_bytes;
  }
}

void qbuffer_iter_prev_part(qbuffer_t* buf, qbuffer_iter_t* iter)
{
  qbuffer_part_t* qbp;

  deque_it_back_one(sizeof(qbuffer_part_t), & iter->iter);

  qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
  iter->offset = qbp->end_offset - qbp->len_bytes;
}

void qbuffer_iter_floor_part(qbuffer_t* buf, qbuffer_iter_t* iter)
{
  deque_iterator_t d_start = deque_begin( & buf->deque );
  deque_iterator_t d_end = deque_end( & buf->deque );

  if( deque_it_equals(iter->iter, d_end) ) {
    if( deque_it_equals(iter->iter, d_start) ) {
      // We're at the beginning. Do nothing.
      return;
    }

    // If we're at the end, just go back one.
    deque_it_back_one(sizeof(qbuffer_part_t), & iter->iter);
  }

  {
    // Now, just set the offset appropriately.
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
    iter->offset = qbp->end_offset - qbp->len_bytes;
  }
}


void qbuffer_iter_ceil_part(qbuffer_t* buf, qbuffer_iter_t* iter)
{
  deque_iterator_t d_end = deque_end( & buf->deque );

  if( deque_it_equals(iter->iter, d_end) ) {
    // We're at the end. Do nothing.
  } else {
    qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
    iter->offset = qbp->end_offset;
    deque_it_forward_one(sizeof(qbuffer_part_t), & iter->iter);
  }
}


/* Advances an iterator using linear search. 
 */
void qbuffer_iter_advance(qbuffer_t* buf, qbuffer_iter_t* iter, int64_t amt)
{
  deque_iterator_t d_begin = deque_begin( & buf->deque );
  deque_iterator_t d_end = deque_end( & buf->deque );

  if( amt >= 0 ) {
    // forward search.
    iter->offset += amt;
    while( ! deque_it_equals(iter->iter, d_end) ) {
      qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
      if( iter->offset < qbp->end_offset ) {
        // it's in this one.
        return;
      }
      deque_it_forward_one(sizeof(qbuffer_part_t), & iter->iter);
    }
  } else {
    // backward search.
    iter->offset += amt; // amt is negative

    if( ! deque_it_equals( iter->iter, d_end ) ) {
      // is it within the current buffer?
      qbuffer_part_t* qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
      if( iter->offset >= qbp->end_offset - qbp->len_bytes ) {
        // it's in this one.
        return;
      }
    }

    // now we have a valid deque element.
    do {
      qbuffer_part_t* qbp;

      deque_it_back_one(sizeof(qbuffer_part_t), & iter->iter);

      qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter->iter);
      if( iter->offset >= qbp->end_offset - qbp->len_bytes ) {
        // it's in this one.
        return;
      }
    } while( ! deque_it_equals(iter->iter, d_begin) );
  }
}




// find buffer iterator part in logarithmic time
// finds an offset in the window [offset_start,offset_end]
// (in other words, offset might not start at 0)
qbuffer_iter_t qbuffer_iter_at(qbuffer_t* buf, int64_t offset)
{
  qbuffer_iter_t ret;
  deque_iterator_t first = deque_begin(& buf->deque);
  deque_iterator_t last = deque_end(& buf->deque);
  deque_iterator_t middle;
  qbuffer_part_t* qbp;
  ssize_t num_parts = deque_it_difference(sizeof(qbuffer_part_t), last, first);
  ssize_t half;

  while( num_parts > 0 ) {
    half = num_parts >> 1;
    middle = first;

    deque_it_forward_n(sizeof(qbuffer_part_t), &middle, half);

    qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), middle);
    if( offset < qbp->end_offset ) {
      num_parts = half;
    } else {
      first = middle;
      deque_it_forward_one(sizeof(qbuffer_part_t), &first);
      num_parts = num_parts - half - 1;
    }
  }

  if( deque_it_equals(first, last) ) {
    ret = qbuffer_end(buf);
  } else {
    qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), first);
    ret.offset = offset;
    ret.iter = first;
  }
  return ret;
}

err_t qbuffer_to_iov(qbuffer_t* buf, qbuffer_iter_t start, qbuffer_iter_t end, 
                     size_t max_iov, struct iovec *iov_out, 
                     qbytes_t** bytes_out /* can be NULL */,
                     size_t *iovcnt_out)
{
  deque_iterator_t d_end = deque_end(& buf->deque);
  deque_iterator_t iter;
  qbuffer_part_t* qbp;
  size_t i = 0;

  iter = start.iter;

  // invalid range!
  if( start.offset > end.offset ) {
    *iovcnt_out = 0;
    return EINVAL;
  }

  if( deque_it_equals(iter, d_end) ) {
    // start is actually pointing to the end of the deque. no data.
    *iovcnt_out = 0;
    return 0;
  }

  if( deque_it_equals(iter, end.iter) ) {
    // we're only pointing to a single block.
    qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter);
    if( i >= max_iov ) goto error_nospace;
    iov_out[i].iov_base = PTR_ADDBYTES(qbp->bytes->data, qbp->skip_bytes + (start.offset - (qbp->end_offset - qbp->len_bytes)));
    iov_out[i].iov_len = end.offset - start.offset;
    if( bytes_out ) bytes_out[i] = qbp->bytes;
    if( iov_out[i].iov_len > 0 ) i++;
  } else {
    // otherwise, there's a possibly partial block in start.
    qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter);
    if( i >= max_iov ) goto error_nospace;
    iov_out[i].iov_base = PTR_ADDBYTES(qbp->bytes->data, qbp->skip_bytes + (start.offset - (qbp->end_offset - qbp->len_bytes)));
    iov_out[i].iov_len = qbp->end_offset - start.offset;
    if( bytes_out ) bytes_out[i] = qbp->bytes;
    // store it if we had any data there.
    if( iov_out[i].iov_len > 0 ) i++;


    // Now, on to the next.
    deque_it_forward_one(sizeof(qbuffer_part_t), &iter);

    // until we get to the same block as end, we need to store full blocks.
    while( ! deque_it_equals( iter, end.iter ) ) {
      if( deque_it_equals( iter, d_end ) ) {
        // error: end is not in deque.
        *iovcnt_out = 0;
        return EINVAL;
      }

      qbp = (qbuffer_part_t*) deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter);
      if( i >= max_iov ) goto error_nospace;
      iov_out[i].iov_base = PTR_ADDBYTES(qbp->bytes->data, qbp->skip_bytes);
      iov_out[i].iov_len = qbp->len_bytes;
      if( bytes_out ) bytes_out[i] = qbp->bytes;
      // store it if we had any data there.
      if( iov_out[i].iov_len > 0 ) i++;

      // Now, on to the next.
      deque_it_forward_one(sizeof(qbuffer_part_t), &iter);
    }

    // at the end of the loop
    // is there any data in end?
    if( deque_it_equals(iter, d_end) ) {
      // we're currently pointing to the end; no need to add more.
    } else {
      qbp = deque_it_get_cur_ptr(sizeof(qbuffer_part_t), iter);
      // add a partial end block. We know it's different from
      // start since we handled that above.
      if( i >= max_iov ) goto error_nospace;
      iov_out[i].iov_base = PTR_ADDBYTES(qbp->bytes->data, qbp->skip_bytes);
      iov_out[i].iov_len = end.offset - (qbp->end_offset - qbp->len_bytes);
      if( bytes_out ) bytes_out[i] = qbp->bytes;
      if( iov_out[i].iov_len > 0 ) i++;
    }
  }

  *iovcnt_out = i;
  return 0;

error_nospace:
  *iovcnt_out = 0;
  return EMSGSIZE; // EOVERFLOW or ENOBUFS would make sense too
}

err_t qbuffer_flatten(qbuffer_t* buf, qbuffer_iter_t start, qbuffer_iter_t end, qbytes_t** bytes_out)
{
  int64_t num_bytes = qbuffer_iter_num_bytes(start, end);
  ssize_t num_parts = qbuffer_iter_num_parts(start, end);
  struct iovec* iov = NULL;
  size_t iovcnt;
  size_t i,j;
  qbytes_t* ret;
  int iov_onstack;
  err_t err;
 
  if( num_bytes < 0 || num_parts < 0 || start.offset < buf->offset_start || end.offset > buf->offset_end ) return EINVAL;

  err = qbytes_create_calloc(&ret, num_bytes);
  if( err ) return err;

  MAYBE_STACK_ALLOC(num_parts*sizeof(struct iovec), iov, iov_onstack);
  if( ! iov ) {
    qbytes_release(ret);
    return ENOMEM;
  }

  err = qbuffer_to_iov(buf, start, end, num_parts, iov, NULL, &iovcnt);
  if( err ) {
    MAYBE_STACK_FREE(iov, iov_onstack);
    qbytes_release(ret);
    return err;
  }

  j = 0;
  for( i = 0; i < iovcnt; i++ ) {
    memcpy(PTR_ADDBYTES(ret->data, j), iov[i].iov_base, iov[i].iov_len);
    j += iov[i].iov_len;
  }

  MAYBE_STACK_FREE(iov, iov_onstack);

  *bytes_out = ret;
  return 0;
}

/*
err_t qbuffer_clone(qbuffer_t* buf, qbuffer_iter_t start, qbuffer_iter_t end, qbuffer_ptr_t* buf_out)
{
  int64_t num_bytes = qbuffer_iter_num_bytes(start, end);
  ssize_t num_parts = qbuffer_iter_num_parts(start, end);
  qbytes_t** bytes = NULL;
  struct iovec* iov = NULL;
  size_t iovcnt;
  size_t i;
  int iov_onstack;
  int bytes_onstack;
  err_t err;
  qbuffer_ptr_t ret = NULL;
 
  if( num_bytes < 0 || num_parts < 0 || start.offset < buf->offset_start || end.offset > buf->offset_end ) return EINVAL;

  err = qbuffer_create(&ret);
  if( err ) return err;

  MAYBE_STACK_ALLOC(num_parts*sizeof(struct iovec), iov, iov_onstack);
  MAYBE_STACK_ALLOC(num_parts*sizeof(qbytes_t*), bytes, bytes_onstack);
  if( ! iov || ! bytes ) {
    err = ENOMEM;
    goto error;
  }

  err = qbuffer_to_iov(buf, start, end, num_parts, iov, bytes, &iovcnt);
  if( err ) goto error;

  // now append them all to our present buffer.
  for( i = 0; i < iovcnt; i++ ) {
    int64_t skip = PTR_DIFFBYTES(iov[i].iov_base, bytes[i]->data);
    int64_t len = iov[i].iov_len;

    if( skip < 0 || skip + len > bytes[i]->len ) {
      err = EINVAL;
      goto error;
    }

    qbuffer_append(ret, bytes[i], skip, len);
  }

  MAYBE_STACK_FREE(iov, iov_onstack);
  MAYBE_STACK_FREE(bytes, bytes_onstack);

  *buf_out = ret;
  return 0;

error:
  MAYBE_STACK_FREE(iov, iov_onstack);
  MAYBE_STACK_FREE(bytes, bytes_onstack);
  qbuffer_destroy(ret);
  return err;
}
*/

err_t qbuffer_copyout(qbuffer_t* buf, qbuffer_iter_t start, qbuffer_iter_t end, void* ptr, size_t ret_len)
{
  int64_t num_bytes = qbuffer_iter_num_bytes(start, end);
  ssize_t num_parts = qbuffer_iter_num_parts(start, end);
  struct iovec* iov = NULL;
  size_t iovcnt;
  size_t i,j;
  int iov_onstack;
  err_t err;
 
  if( num_bytes < 0 || num_parts < 0 || start.offset < buf->offset_start || end.offset > buf->offset_end ) return EINVAL;

  MAYBE_STACK_ALLOC(num_parts*sizeof(struct iovec), iov, iov_onstack);
  if( ! iov ) return ENOMEM;

  err = qbuffer_to_iov(buf, start, end, num_parts, iov, NULL, &iovcnt);
  if( err ) goto error;

  j = 0;
  for( i = 0; i < iovcnt; i++ ) {
    if( j + iov[i].iov_len > ret_len ) goto error_nospace;
    memcpy(PTR_ADDBYTES(ptr, j), iov[i].iov_base, iov[i].iov_len);
    j += iov[i].iov_len;
  }

  MAYBE_STACK_FREE(iov, iov_onstack);
  return 0;

error_nospace:
  err = EMSGSIZE;
error:
  MAYBE_STACK_FREE(iov, iov_onstack);
  return err;
}

err_t qbuffer_copyin(qbuffer_t* buf, qbuffer_iter_t start, qbuffer_iter_t end, const void* ptr, size_t ret_len)
{
  int64_t num_bytes = qbuffer_iter_num_bytes(start, end);
  ssize_t num_parts = qbuffer_iter_num_parts(start, end);
  struct iovec* iov = NULL;
  size_t iovcnt;
  size_t i,j;
  int iov_onstack;
  err_t err;
 
  if( num_bytes < 0 || num_parts < 0 || start.offset < buf->offset_start || end.offset > buf->offset_end ) return EINVAL;

  MAYBE_STACK_ALLOC(num_parts*sizeof(struct iovec), iov, iov_onstack);
  if( ! iov ) return ENOMEM;

  err = qbuffer_to_iov(buf, start, end, num_parts, iov, NULL, &iovcnt);
  if( err ) goto error;

  j = 0;
  for( i = 0; i < iovcnt; i++ ) {
    if( j + iov[i].iov_len > ret_len ) goto error_nospace;
    memcpy(iov[i].iov_base, PTR_ADDBYTES(ptr, j), iov[i].iov_len);
    j += iov[i].iov_len;
  }

  MAYBE_STACK_FREE(iov, iov_onstack);
  return 0;

error_nospace:
  err = EMSGSIZE;
error:
  MAYBE_STACK_FREE(iov, iov_onstack);
  return err;
}

err_t qbuffer_copyin_buffer(qbuffer_t* dst, qbuffer_iter_t dst_start, qbuffer_iter_t dst_end,
                            qbuffer_t* src, qbuffer_iter_t src_start, qbuffer_iter_t src_end)
{
  int64_t dst_num_bytes = qbuffer_iter_num_bytes(dst_start, dst_end);
  ssize_t dst_num_parts = qbuffer_iter_num_parts(dst_start, dst_end);
  int64_t src_num_bytes = qbuffer_iter_num_bytes(src_start, src_end);
  ssize_t src_num_parts = qbuffer_iter_num_parts(src_start, src_end);
  struct iovec* iov = NULL;
  size_t iovcnt;
  size_t i;
  int iov_onstack;
  err_t err;
  qbuffer_iter_t dst_cur, dst_cur_end;
 
  if( dst == src ) return EINVAL;
  if( dst_num_bytes < 0 || dst_num_parts < 0 || dst_start.offset < dst->offset_start || dst_end.offset > dst->offset_end ) return EINVAL;
  if( src_num_bytes < 0 || src_num_parts < 0 || src_start.offset < src->offset_start || src_end.offset > src->offset_end ) return EINVAL;

  MAYBE_STACK_ALLOC(src_num_parts*sizeof(struct iovec), iov, iov_onstack);
  if( ! iov ) return ENOMEM;

  err = qbuffer_to_iov(src, src_start, src_end, src_num_parts, iov, NULL, &iovcnt);
  if( err ) goto error;

  dst_cur = dst_start;
  for( i = 0; i < iovcnt; i++ ) {
    dst_cur_end = dst_cur;
    qbuffer_iter_advance(dst, &dst_cur_end, iov[i].iov_len);
    err = qbuffer_copyin(dst, dst_cur, dst_cur_end, iov[i].iov_base, iov[i].iov_len);
    if( err ) goto error;
    dst_cur = dst_cur_end;
  }

  MAYBE_STACK_FREE(iov, iov_onstack);
  return 0;

error:
  MAYBE_STACK_FREE(iov, iov_onstack);
  return err;
}

err_t qbuffer_memset(qbuffer_t* buf, qbuffer_iter_t start, qbuffer_iter_t end, unsigned char byte)
{
  int64_t num_bytes = qbuffer_iter_num_bytes(start, end);
  ssize_t num_parts = qbuffer_iter_num_parts(start, end);
  struct iovec* iov = NULL;
  size_t iovcnt;
  size_t i;
  int iov_onstack;
  err_t err;
 
  if( num_bytes < 0 || num_parts < 0 || start.offset < buf->offset_start || end.offset > buf->offset_end ) return EINVAL;

  MAYBE_STACK_ALLOC(num_parts*sizeof(struct iovec), iov, iov_onstack);
  if( ! iov ) return ENOMEM;

  err = qbuffer_to_iov(buf, start, end, num_parts, iov, NULL, &iovcnt);
  if( err ) goto error;

  for( i = 0; i < iovcnt; i++ ) {
    memset(iov[i].iov_base, byte, iov[i].iov_len);
  }

  MAYBE_STACK_FREE(iov, iov_onstack);
  return 0;

error:
  MAYBE_STACK_FREE(iov, iov_onstack);
  return err;
}




#if 0

/*
int64_t qbuffer_num_parts_after(qbuffer_iter iter)
{
  int64_t count = 0;
  // otherwise, recompute number of parts
  for( qbuffer_part_t* cur = iter.cur_part;
       cur;
       cur = cur->next ) {
    count++;
  }
  return count;
}

int64_t qbuffer_num_parts(qbuffer_t* buf)
{
  return qbuffer_num_parts_after(qbuffer_start(buf));
}

typedef struct qbuffer_ptr_len_s {
  void* ptr;
  int64_t len;
} qbuffer_ptr_len_t;

static inline
qbuffer_ptr_len_t qbuffer_part_ptrlen(qbuffer_part_t* part, int64_t skip)
{
  // copy from cur to data + len
  int64_t p_offset = part->offset + skip;
  int64_t p_len = part->len;
  qbuffer_ptr_len_t ret;
  if( p_offset + p_len > cur->bytes->len ) {
    p_len = cur->bytes->len - p_offset;
  }
  if( p_len > 0 ) {
    ret.ptr = part->data + p_offset;
    ret.len = p_len;
  } else {
    ret.ptr = NULL;
    ret.len = 0;
  }
  return ret;
}

int64_t qbuffer_len_after(qbuffer_t* buf, qbuffer_iter iter)
{
  int64_t len = 0;

  // compute the length
  for( qbuffer_part_t* cur = iter.cur_part;
       cur;
       cur = cur->next ) {
    int64_t skip = 0;
    if( cur == iter.cur_part ) skip = iter.cur_offset;
    x = qbuffer_part_ptrlen(cur, skip);
    len += x.len;
  }
  return len;
}

int64_t qbuffer_len(qbuffer_t* buf)
{
  return qbuffer_len_after(buf, qbuffer_start(buf));
}
*/
// adds to the reference count of f
void qio_channel_init(qio_channel_t* ch, qio_file_t* f, int64_t start_offset, int64_t max_len, int* err_out)
{
  int err;

  err = INIT_LOCK(&ch->lock);
  if( err ) {
    *err_out = err;
    return;
  }

  qio_file_retain(f);
  ch->file = f;
  ch->pos = start_offset;
  ch->max_pos = start_offset + max_len; 
  rc = qbuffer_init(&ch->buf);
  if( rc ) {
    qio_file_release(f);
    *err_out = rc;
    return;
  }

  *err_out = 0;
  return;
}

void qio_channel_destroy(qio_channel_t* ch, int* err_out)
{
  int err;

  err = DESTROY_LOCK(&ch->lock);
  if( err ) {
    *err_out = err;
  }

  qio_file_release(ch->file);
  qbuffer_destroy(&ch->buf);

  *err_out = 0;
  return;
}

int qio_channel_locked_append_part(qio_channel_t* ch)
{
  int err = EINVAL;

  // actually read some data!
  switch( ch->method ) {
    case QIO_PREADWRITE:
      {
        qbytes_t* bytes = NULL;
        int64_t num_read = 0;
        // allocate a part and read into it.
        err = qbytes_create_iobuf(&bytes);
        if( err ) return err;
        if( ch->reading ) {
          // read into it
          qsys_preadv(ch->file->fd, ch->iter, ch->pos, &num_read, &err);
          if( err ) return err;
        }
        // advance channel...
        ch->pos += num_read;
      }
      break;
    case QIO_MMAP:
      // get it from the memory map...
      // figure out a pointer to the right spot in the file.
      {
        LOCK(ch->file->lock);
        qbuffer_iter_t iter = qbuffer_start(ch->file->mmaped);
        qbuffer_iter_advance(&iter, ch->pos);
        ret = qbuffer_append_buffer(&ch->buf, ch->file->mmapped);
        assert(0); // TODO
        UNLOCK(ch->file->lock);
      }
      break;
    case QIO_LIBEVENT:
      // allocate it in the usual manner
      // read into it with evbuffer_add_reference
      {
        qbytes_t* bytes = NULL;
        int64_t num_read = 0;
        // allocate a part and read into it.
        err = qbytes_create_iobuf(&bytes);
        if( err ) return err;
        if( ch->reading ) {
          // read into it
          qsys_readv(ch->file->fd, ch->iter, &num_read, &err);
          if( err ) return err;
        }
        // advance channel
        ch->pos += num_read;
        // TODO -- integrate with libevent; check readiness, wait on
        // sync var
        assert(0);
        // did we read as much as we should've?
      }
      break;
    }
  }
}

// Assuming that the channel is locked,
// read (or allocate) buffer space
void qio_channel_locked_require(qio_channel_t* ch, int64_t need_bytes, int *err_out)
{
  // how much space is there after the iterator?
  int64_t avail = qbuffer_len_after(&ch->buf, ch->iter);
  if( need_bytes <= avail ) {
    // OK
    *err_out = 0;
    return;
  } else {
    // Need to read forward; need to get need_bytes.
    qio_channel_get_next_part
  }
}


// read the next part of the file, assuming the channel is locked.
void qio_channel_xxx(qio_channel_t* ch, int64_t min_length, int64_t max_length, int* err_out)
{
  void* ptr;
  int rc;
  int64_t len = qio_mmap_chunk;
  qbytes_t* bytes;

  if( ch->pos + len >= ch->len ) {
    len = ch->len - ch->pos;
  }

  ptr = mmap(NULL, len, PROT_READ, MAP_SHARED, ch->file.fd, ch->pos);
  if( ptr == MAP_FAILED ) {
    *err_out = errno;
    return;
  }

  rc = qbytes_create_generic(&bytes, ptr, len, qbytes_free_munmap);
  if( rc ) {
    *err_out = rc;
    return;
  }

  rc = qbuffer_append(&ch->buf, bytes, 0, len);
  if( rc ) {
    *err_out = rc;
    return;
  }

  ch->pos += len;
  *err_out = 0;
}

// Write any data before the buffer position.
void qio_channel_write_splice_locked(qio_channel_t* ch, int* err_out)
{
  ssize_t sz;
  int rc;
  int err;
  struct iovec* iov;
  int64_t num_parts_before;
  loff_t offset;
  loff_t* offset_ptr = NULL;

  // make sure that we have a pipe
  if( ch->pipefd == -1 ) {
    qio_pipe(&ch->pipefd_read, &ch->pipefd_write, &err);
    if( err ) {
      *err_out = err;
      return;
    }
    // try increasing the pipe size..
    qio_fcntl(ch->pipefd_read, F_SETPIPE_SZ, large, &rc, &err);
    if( err ) {
      *err_out = err;
      return;
    }
  }

  if( ch->file.fdflags & QIO_FDFLAG_SEEKABLE ) {
    // set the output position...
    offset = ch->pos;
    offset_ptr = &offset;
  }

  num_parts_before = qbuffer_num_parts_before(&ch->buf);

  rc = qbuffer_prepare_iov_before(&ch->buf, iov, num_parts_before);

  // now, in chunks of data not exceeding the pipe size
  // - vmsplice data into the pipe
  // - splice the data out of the pipe
  f_more = SPLICE_F_MORE;
  loop {
    if( last iteration ) f_more = 0;

    vmsplice(ch->pipefd_write, iovec, num_parts_before, SPLICE_F_GIFT );
    splice(ch->pipefd_read, NULL, ch->file.fd, offset_ptr, len, SPLICE_F_MOVE | f_more);
  }
}
#endif

