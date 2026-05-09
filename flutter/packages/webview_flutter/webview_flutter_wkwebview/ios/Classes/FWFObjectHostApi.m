// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FWFObjectHostApi.h"
#import <objc/runtime.h>
#import "FWFDataConverters.h"
#import "FWFURLHostApi.h"

@interface FWFObjectFlutterApiImpl ()
// BinaryMessenger must be weak to prevent a circular reference with the host API it
// references.
@property(nonatomic, weak) id<FlutterBinaryMessenger> binaryMessenger;
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFObjectFlutterApiImpl
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self initWithBinaryMessenger:binaryMessenger];
  if (self) {
    _binaryMessenger = binaryMessenger;
    _instanceManager = instanceManager;
  }
  return self;
}

- (long)identifierForObject:(NSObject *)instance {
  return [self.instanceManager identifierWithStrongReferenceForInstance:instance];
}

- (void)observeValueForObject:(NSObject *)instance
                      keyPath:(NSString *)keyPath
                       object:(NSObject *)object
                       change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                   completion:(void (^)(FlutterError *_Nullable))completion {
  NSMutableArray<FWFNSKeyValueChangeKeyEnumData *> *changeKeys = [NSMutableArray array];
  NSMutableArray<id> *changeValues = [NSMutableArray array];

  [change enumerateKeysAndObjectsUsingBlock:^(NSKeyValueChangeKey key, id value, BOOL *stop) {
    [changeKeys addObject:FWFNSKeyValueChangeKeyEnumDataFromNativeNSKeyValueChangeKey(key)];
    BOOL isIdentifier = NO;
    if ([self.instanceManager containsInstance:value]) {
      isIdentifier = YES;
    } else if (object_getClass(value) == [NSURL class]) {
      FWFURLFlutterApiImpl *flutterApi =
          [[FWFURLFlutterApiImpl alloc] initWithBinaryMessenger:self.binaryMessenger
                                                instanceManager:self.instanceManager];
      [flutterApi create:value
              completion:^(FlutterError *error) {
                if (error) {
                  NSLog(@"FWFURLFlutterApi create error: %@", error);
                }
              }];
      isIdentifier = YES;
    }

    id returnValue = isIdentifier
                         ? @([self.instanceManager identifierWithStrongReferenceForInstance:value])
                         : value;
    [changeValues addObject:[FWFObjectOrIdentifier makeWithValue:returnValue
                                                    isIdentifier:isIdentifier]];
  }];

  NSInteger objectIdentifier =
      [self.instanceManager identifierWithStrongReferenceForInstance:object];
  [self observeValueForObjectWithIdentifier:[self identifierForObject:instance]
                                    keyPath:keyPath
                           objectIdentifier:objectIdentifier
                                 changeKeys:changeKeys
                               changeValues:changeValues
                                 completion:completion];
}
@end

@implementation FWFObject
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self init];
  if (self) {
    _objectApi = [[FWFObjectFlutterApiImpl alloc] initWithBinaryMessenger:binaryMessenger
                                                          instanceManager:instanceManager];
  }
  return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  // KVO callbacks may arrive on a background thread (e.g. from WKWebView's
  // internal queues). Flutter platform channels must be called on the main
  // thread; dispatch to it if necessary to avoid the
  // "channel sent a message on a non-platform thread" crash.
  if ([NSThread isMainThread]) {
    [self.objectApi observeValueForObject:self
                                  keyPath:keyPath
                                   object:object
                                   change:change
                               completion:^(FlutterError *error) {
                                 if (error) {
                                   NSLog(@"FWFObject observeValueForKeyPath error: %@", error);
                                 }
                               }];
  } else {
    // Copy change dict to prevent potential mutation across thread boundary.
    NSDictionary<NSKeyValueChangeKey, id> *changeCopy = [change copy];
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.objectApi observeValueForObject:self
                                    keyPath:keyPath
                                     object:object
                                     change:changeCopy
                                 completion:^(FlutterError *error) {
                                   if (error) {
                                   NSLog(@"FWFObject observeValueForKeyPath error: %@", error);
                                 }
                                 }];
    });
  }
}
@end

@interface FWFObjectHostApiImpl ()
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFObjectHostApiImpl
- (instancetype)initWithInstanceManager:(FWFInstanceManager *)instanceManager {
  self = [self init];
  if (self) {
    _instanceManager = instanceManager;
  }
  return self;
}

- (NSObject *)objectForIdentifier:(NSInteger)identifier {
  return (NSObject *)[self.instanceManager instanceForIdentifier:identifier];
}

- (void)addObserverForObjectWithIdentifier:(NSInteger)identifier
                        observerIdentifier:(NSInteger)observer
                                   keyPath:(nonnull NSString *)keyPath
                                   options:
                                       (nonnull NSArray<FWFNSKeyValueObservingOptionsEnumData *> *)
                                           options
                                     error:(FlutterError *_Nullable *_Nonnull)error {
  NSKeyValueObservingOptions optionsInt = 0;
  for (FWFNSKeyValueObservingOptionsEnumData *data in options) {
    optionsInt |= FWFNativeNSKeyValueObservingOptionsFromEnumData(data);
  }
  [[self objectForIdentifier:identifier] addObserver:[self objectForIdentifier:observer]
                                          forKeyPath:keyPath
                                             options:optionsInt
                                             context:nil];
}

- (void)removeObserverForObjectWithIdentifier:(NSInteger)identifier
                           observerIdentifier:(NSInteger)observer
                                      keyPath:(nonnull NSString *)keyPath
                                        error:(FlutterError *_Nullable *_Nonnull)error {
  [[self objectForIdentifier:identifier] removeObserver:[self objectForIdentifier:observer]
                                             forKeyPath:keyPath];
}

- (void)disposeObjectWithIdentifier:(NSInteger)identifier
                              error:(FlutterError *_Nullable *_Nonnull)error {
  [self.instanceManager removeInstanceWithIdentifier:identifier];
}
@end
