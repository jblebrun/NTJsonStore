//
//  NTJsonObjectCache.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/31/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


#import "NTJsonStore+Private.h"


//#define DEBUG_CACHE


#ifdef DEBUG_CACHE
#   define CACHE_LOG(format, ...) LOG_DBG(format, ##__VA_ARGS__)
#else
#   define CACHE_LOG(format, ...)
#endif



static const int DEFAULT_CACHE_SIZE = 50;



#pragma mark - NTJsonObjectCacheItem


@implementation NTJsonObjectCacheItem


-(id)proxyObject
{
    id proxyObject = _proxyObject;
    
    if ( !proxyObject )
    {
        proxyObject = [[NTJsonDictionary alloc] initWithCacheItem:self];
        _proxyObject = proxyObject;
    }
    
    return proxyObject;
}


-(id)initWithCache:(NTJsonObjectCache *)cache rowId:(NTJsonRowId)rowId json:(NSDictionary *)json
{
    self = [super init];
    
    if ( self )
    {
        _cache = cache;
        _rowId = rowId;
        _json = json;
        _isInUse = NO;
    }
    
    return self;
}


@end


#pragma mark - NTJsonObjectCache


@implementation NTJsonObjectCache
{
    NSRecursiveLock* _cacheLock;
}

-(id)initWithCacheSize:(int)cacheSize
{
    self = [super init];
    
    if ( self )
    {
        _cacheSize = cacheSize;
        _items = [NSMutableDictionary dictionary];
        _cachedItems = [NSMutableArray array];
        _cacheLock = [NSRecursiveLock new];
    }

    return self;
}


-(id)initWithDeallocQueue:(dispatch_queue_t)deallocQueue
{
    return [self initWithCacheSize:DEFAULT_CACHE_SIZE];
}


-(void)setCacheSize:(int)cacheSize
{
    if ( cacheSize == _cacheSize )
        return ;
    
    _cacheSize = cacheSize;
    
    [self purgeCacheWithFlushAll:NO];
}


-(void)proxyDeallocedForCacheItem:(NTJsonObjectCacheItem *)cacheItem
{
    dispatch_async(_deallocQueue, ^{
        CACHE_LOG(@"Caching - %d", (int)cacheItem.rowId);

        cacheItem.isInUse = NO;
        [_cachedItems addObject:cacheItem]; // newest are at end of the list.

        if ( !_cachedItems.count > _cacheSize )
            [self purgeCacheWithFlushAll:NO];
    });
}


-(NSDictionary *)jsonWithRowId:(NTJsonRowId)rowId
{
    NTJsonObjectCacheItem *item = _items[@(rowId)];
    
    if ( !item )
    {
        CACHE_LOG(@"Cache miss - %d", (int)rowId);
        return nil;
    }
    
    if ( !item.isInUse )
    {
        CACHE_LOG(@"Cache Hit (not in use) - %d", (int)rowId);
        // coming back into action!
        item.isInUse = YES;
        [_cacheLock lock];
        [_cachedItems removeObjectIdenticalTo:item];    // it is no longer in our cache, since it's active
        [_cacheLock unlock];
    }
    else
    {
        CACHE_LOG(@"Cache Hit (already in use) - %d", (int)rowId);
    }
    
    return item.proxyObject;
}


-(NSDictionary *)addJson:(NSDictionary *)json withRowId:(NTJsonRowId)rowId
{
    CACHE_LOG(@"adding - %d", (int)rowId);

    NTJsonObjectCacheItem *currentItem = _items[@(rowId)];
    
    if ( currentItem )
    {
        [self removeCacheItem:currentItem];
        currentItem = nil;
    }
    
    NTJsonObjectCacheItem *item = [[NTJsonObjectCacheItem alloc] initWithCache:self rowId:rowId json:json];
    
    _items[@(rowId)] = item;
    item.isInUse = YES;
    
    return item.proxyObject;
}


-(void)removeCacheItem:(NTJsonObjectCacheItem *)item
{
    item.cache = nil;   // unlink from cache so proxyDeallocedForCacheItem: will not be called
    [_cacheLock lock];
    [_cachedItems removeObjectIdenticalTo:item];
    [_cacheLock unlock];
    [_items removeObjectForKey:@(item.rowId)];
}


-(void)removeObjectWithRowId:(NTJsonRowId)rowId
{
    NTJsonObjectCacheItem *item = _items[@(rowId)];
    
    if ( item )
        [self removeCacheItem:item];
}


-(void)purgeCacheWithFlushAll:(BOOL)flushAll
{
    int cacheSize = (flushAll) ? 0 : _cacheSize;

    CACHE_LOG(@"purging - %d", (int)item.rowId);

    // clear any unused values from the cache...
    do {

        [_cacheLock lock];

        NTJsonObjectCacheItem *item = _cachedItems.firstObject;  // grab oldest...
        if (item) [self removeCacheItem:item];
        NSUInteger size = _cachedItems.count;

        [_cacheLock unlock];


        if ( size <= cacheSize ) break;

    } while (true);

}


-(void)flush
{
    [self purgeCacheWithFlushAll:YES];
}


-(void)removeAll
{
    for(NTJsonObjectCacheItem *item in _items.allValues)
        [self removeCacheItem:item];
}


@end
