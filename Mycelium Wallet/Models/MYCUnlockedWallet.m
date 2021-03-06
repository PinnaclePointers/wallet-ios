//
//  MYCUnlockedWallet.m
//  Mycelium Wallet
//
//  Created by Oleg Andreev on 08.10.2014.
//  Copyright (c) 2014 Mycelium. All rights reserved.
//

#import "MYCUnlockedWallet.h"
#import "MYCWallet.h"
#import <Security/Security.h>

#define kMasterSeedName @"MasterSeed"

static BOOL MYCBypassMissingPasscode = 0;

@interface MYCUnlockedWallet ()
@end

@implementation MYCUnlockedWallet {
}

@synthesize mnemonic=_mnemonic;

+ (void) setBypassMissingPasscode {
    MYCBypassMissingPasscode = YES;
}

- (NSString*) serviceName {
    return @"MyceliumWallet";
}

- (BTCMnemonic*) mnemonic {
    if (!_mnemonic) {
        NSError* error = nil;
        NSData* data = [self readItemWithName:kMasterSeedName error:&error];
        if (!data) {
            MYCLog(@"MYCUnlockedWallet: Cannot read mnemonic from keychain: %@", error);
            self.error = error;
            return nil;
        }
        _mnemonic = [[BTCMnemonic alloc] initWithData:data];
    }
    return _mnemonic;
}

- (void) setMnemonic:(BTCMnemonic *)mnemonic {

    _mnemonic = mnemonic;
    NSError* error = nil;
    NSData* data = mnemonic.dataWithSeed ?: [NSData data];
    if (![self writeItem:data withName:kMasterSeedName accessibility:kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly error:&error]) {
        MYCLog(@"MYCUnlockedWallet: Cannot write mnemonic to keychain: %@", error);
        self.error = error;
        return;
    }
}



//- (BTCMnemonic*) mnemonic
//{
//    if (!_mnemonic)
//    {
//        CFDictionaryRef attributes = NULL;
//        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)[self keychainSearchRequestForMnemonic],
//                                              (CFTypeRef *)&attributes);
//        if (status == errSecSuccess)
//        {
//            NSDictionary* attrs = (__bridge id)attributes;
//
//            NSData* data = attrs[(__bridge id)kSecValueData];
//
//            if (data && data.length > 0)
//            {
//                _mnemonic = [[BTCMnemonic alloc] initWithData:data];
//            }
//            else
//            {
//                // Not found the data.
//                MYCError(@"MYCUnlockedWallet: read the keychain item, but the data is %@ (attrs: %@)", data, attrs);
//            }
//        }
//        else if (status == errSecItemNotFound)
//        {
//            // Not found - we have no mnemonic.
//            _mnemonic = nil;
//        }
//        else
//        {
//            // if status == -34018, add proper Shared Keychain entitlements
//            // http://stackoverflow.com/questions/20344255/secitemadd-and-secitemcopymatching-returns-error-code-34018-errsecmissingentit
//            MYCError(@"MYCUnlockedWallet: failed searching iOS keychain (getting mnemonic): %d", (int)status);
//        }
//    }
//    return _mnemonic;
//}
//
//- (void) setMnemonic:(BTCMnemonic *)mnemonic
//{
//    _mnemonic = mnemonic;
//
//    // We cannot update the value, only attributes of the keychain items.
//    // So to update value we delete the item and add a new one.
//
//    SecItemDelete((__bridge CFDictionaryRef)[self keychainSearchRequestForMnemonic]);
//
//    if (mnemonic)
//    {
//        CFDictionaryRef attributes = NULL;
//        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)[self keychainCreateRequestForMnemonic], (CFTypeRef *)&attributes);
//        if (status == errSecSuccess)
//        {
//            // done.
//        }
//        else
//        {
//            MYCError(@"MYCUnlockedWallet: failed to add mnemonic data to iOS keychain: %d", (int)status);
//        }
//    }
//}
//
//// OSStatus values specific to Security framework.
////enum
////{
////    errSecSuccess                               = 0,       /* No error. */
////    errSecUnimplemented                         = -4,      /* Function or operation not implemented. */
////    errSecIO                                    = -36,     /*I/O error (bummers)*/
////    errSecOpWr                                  = -49,     /*file already open with with write permission*/
////    errSecParam                                 = -50,     /* One or more parameters passed to a function where not valid. */
////    errSecAllocate                              = -108,    /* Failed to allocate memory. */
////    errSecUserCanceled                          = -128,    /* User canceled the operation. */
////    errSecBadReq                                = -909,    /* Bad parameter or invalid state for operation. */
////    errSecInternalComponent                     = -2070,
////    errSecNotAvailable                          = -25291,  /* No keychain is available. You may need to restart your computer. */
////    errSecDuplicateItem                         = -25299,  /* The specified item already exists in the keychain. */
////    errSecItemNotFound                          = -25300,  /* The specified item could not be found in the keychain. */
////    errSecInteractionNotAllowed                 = -25308,  /* User interaction is not allowed. */
////    errSecDecode                                = -26275,  /* Unable to decode the provided data. */
////    errSecAuthFailed                            = -25293,  /* The user name or passphrase you entered is not correct. */
////};
//
//- (NSMutableDictionary*) keychainBaseDictForMnemonic
//{
//    return [self keychainBaseDictForItemNamed:kMasterSeedName];
//}
//
//- (NSMutableDictionary*) keychainSearchRequestForMnemonic
//{
//    NSMutableDictionary* dict = [self keychainBaseDictForMnemonic];
//
//    if (self.reason) dict[(__bridge id)kSecUseOperationPrompt] = self.reason;
//    dict[(__bridge id)kSecReturnData] = @YES;
//    dict[(__bridge id)kSecReturnAttributes] = @YES; // when both ReturnData and ReturnAttributes are specified, result is the dictionary.
//
//    return dict;
//}
//
//- (NSMutableDictionary*) keychainCreateRequestForMnemonic
//{
//    NSMutableDictionary* dict = [self keychainBaseDictForMnemonic];
//
//    if (self.reason) dict[(__bridge id)kSecUseOperationPrompt] = self.reason;
//    if (_mnemonic) dict[(__bridge id)kSecValueData] = _mnemonic.dataWithSeed ?: [NSData data];
//    dict[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
//
//    return dict;
//}

- (BTCKeychain*) keychain
{
    if (!_keychain)
    {
        BTCMnemonic* mnemonic = self.mnemonic;
        if (mnemonic) {
            _keychain = (self.wallet.isTestnet ? [mnemonic.keychain bitcoinTestnetKeychain] : [mnemonic.keychain bitcoinMainnetKeychain]);
        }
    }
    return _keychain;
}

- (void) clear
{
    [_mnemonic clear];
    [_keychain clear];
    _mnemonic = nil;
    _keychain = nil;
}

- (void) dealloc
{
    [self clear];
}




#pragma mark - Secret Accessors


- (NSData*) readItemWithName:(NSString*)name error:(NSError**)errorOut {

    MYCLog(@"MYCUnlockedWallet: Reading item with name: %@", name);
    CFDictionaryRef value = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)[self keychainSearchRequestForItemNamed:name],
                                          (CFTypeRef *)&value);
    if (status == errSecSuccess) {
        return ( __bridge_transfer NSData *)value;
    }
    else if (status == errSecItemNotFound) {
        // We have no data stored there yet, so we don't return an error.
        MYCLog(@"MYCUnlockedWallet: Item with name %@ not found", name);
        return nil;
    }

    if (errorOut) *errorOut = [self errorForOSStatus:status];

    return nil;
}

- (BOOL) itemExistsWithName:(NSString*)name error:(NSError**)errorOut {

    //MYCLog(@"MYCUnlockedWallet: Checking if item exists with name: %@", name);
    CFDictionaryRef value = NULL;

    NSMutableDictionary* requestDict = [self keychainBaseDictForItemNamed:name];
    requestDict[(__bridge id)kSecReturnRef] = @YES;
    requestDict[(__bridge id)kSecUseNoAuthenticationUI] = @YES;

    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)[self keychainSearchRequestForItemNamed:name],
                                          (CFTypeRef *)&value);

    if (status == errSecSuccess) {
        return YES;
    }
    else if (status == errSecItemNotFound) {
        return NO;
    }

    if (errorOut) *errorOut = [self errorForOSStatus:status];
    return NO;
}

- (BOOL) writeItem:(NSData*)data withName:(NSString*)name accessibility:(CFTypeRef)accessibility error:(NSError**)errorOut {

    MYCLog(@"MYCUnlockedWallet: Writing %@ bytes with name: %@", @(data.length), name);
    NSParameterAssert(name);
    NSParameterAssert(accessibility);

    // We cannot update the value, only attributes of the keychain items.
    // So to update value we delete the item and add a new one.
    OSStatus status1 = SecItemDelete((__bridge CFDictionaryRef)[self keychainSearchRequestForItemNamed:name]);

    if (status1 != errSecSuccess && status1 != errSecItemNotFound) {
        if (errorOut) *errorOut = [self errorForOSStatus:status1];
        return NO;
    }

    if (!data) {
        MYCLog(@"MYCUnlockedWallet: Writing nil data for name %@", name);
        return YES;
    }

    NSDictionary* createRequest = [self keychainCreateRequestForItemNamed:name data:data accessibility:accessibility];
    CFDictionaryRef attributes = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)createRequest, (CFTypeRef *)&attributes);
    if (status != errSecSuccess) {
        if (errorOut) *errorOut = [self errorForOSStatus:status];
        return NO;
    }
    return YES;
}



#pragma mark - Apple Keychain Helpers


- (NSMutableDictionary*) keychainBaseDictForItemNamed:(NSString*)name {

    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    dict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

    // IMPORTANT: need to save password with both keys: service + account. kSecAttrGeneric as used in Apple's code does not guarantee uniqueness.
    // http://useyourloaf.com/blog/2010/04/28/keychain-duplicate-item-when-adding-password.html
    // http://stackoverflow.com/questions/4891562/ios-keychain-services-only-specific-values-allowed-for-ksecattrgeneric-key
    dict[(__bridge id)kSecAttrService] = self.serviceName;
    dict[(__bridge id)kSecAttrAccount] = name;

    return dict;
}

- (NSMutableDictionary*) keychainSearchRequestForItemNamed:(NSString*)name {

    NSMutableDictionary* dict = [self keychainBaseDictForItemNamed:name];
    if (self.reason) dict[(__bridge id)kSecUseOperationPrompt] = self.reason;
    dict[(__bridge id)kSecReturnData] = @YES;

    return dict;
}

- (NSMutableDictionary*) keychainCreateRequestForItemNamed:(NSString*)name data:(NSData*)data accessibility:(CFTypeRef)accessibility  {

    NSMutableDictionary* dict = [self keychainBaseDictForItemNamed:name];

    if (data) dict[(__bridge id)kSecValueData] = data;

#if TARGET_IPHONE_SIMULATOR
    // Simulator does not support touch id or passcode, but we need to test the UI on simulator,
    // so lets assume it's implicitly unlocked.
    if (accessibility == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) {
        accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    }
#endif

    if (MYCBypassMissingPasscode && (accessibility == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)) {
        MYCLog(@"Downgrading security because passcode is not set.");
        accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    }

    // Need to set access control object to require user enter passcode / touch id every time.
    // For all other accessibility modes we can read items any time device is unlocked.
    if (accessibility == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) {
        SecAccessControlRef sac = SecAccessControlCreateWithFlags(kCFAllocatorDefault, accessibility, kSecAccessControlUserPresence, NULL);
        NSAssert(sac, @"");
        if (sac) {
            dict[(__bridge id)kSecAttrAccessControl] = (__bridge_transfer id)sac;
            dict[(__bridge id)kSecUseNoAuthenticationUI] = @YES; // cargo cult.
        } else {
            MYCLog(@"CANNOT CREATE SecAccessControlRef");
        }
    } else {
        // For all other
        dict[(__bridge id)kSecAttrAccessible] = (__bridge id)accessibility;
    }
    return dict;
}



// OSStatus values specific to Security framework.
//enum
//{
//    errSecSuccess                               = 0,       /* No error. */
//    errSecUnimplemented                         = -4,      /* Function or operation not implemented. */
//    errSecIO                                    = -36,     /*I/O error (bummers)*/
//    errSecOpWr                                  = -49,     /*file already open with with write permission*/
//    errSecParam                                 = -50,     /* One or more parameters passed to a function where not valid. */
//    errSecAllocate                              = -108,    /* Failed to allocate memory. */
//    errSecUserCanceled                          = -128,    /* User canceled the operation. */
//    errSecBadReq                                = -909,    /* Bad parameter or invalid state for operation. */
//    errSecInternalComponent                     = -2070,
//    errSecNotAvailable                          = -25291,  /* No keychain is available. You may need to restart your computer. */
//    errSecDuplicateItem                         = -25299,  /* The specified item already exists in the keychain. */
//    errSecItemNotFound                          = -25300,  /* The specified item could not be found in the keychain. */
//    errSecInteractionNotAllowed                 = -25308,  /* User interaction is not allowed. */
//    errSecDecode                                = -26275,  /* Unable to decode the provided data. */
//    errSecAuthFailed                            = -25293,  /* The user name or passphrase you entered is not correct. */
//};

- (NSError*) errorForOSStatus:(OSStatus)statusCode {
    return [MYCUnlockedWallet errorForOSStatus:statusCode];
}

+ (NSError*) errorForOSStatus:(OSStatus)statusCode {
    NSString* description = nil;
    NSString* codeName = nil;

    switch (statusCode) {
        case errSecSuccess:
            codeName = @"errSecSuccess";
            description = @"No error.";
            break;
        case errSecUnimplemented:
            codeName = @"errSecUnimplemented";
            description = @"Function or operation not implemented.";
            break;
        case errSecIO:
            codeName = @"errSecIO";
            description = @"I/O error (bummers)";
            break;
        case errSecParam:
            codeName = @"errSecParam";
            description = @"One or more parameters passed to a function where not valid.";
            break;
        case errSecAllocate:
            codeName = @"errSecAllocate";
            description = @"Failed to allocate memory.";
            break;
        case errSecUserCanceled:
            codeName = @"errSecUserCanceled";
            description = @"User canceled the operation.";
            break;
        case errSecBadReq:
            codeName = @"errSecBadReq";
            description = @"Bad parameter or invalid state for operation.";
            break;
        case errSecInternalComponent:
            codeName = @"errSecInternalComponent";
            description = @"";
            break;
        case errSecNotAvailable:
            codeName = @"errSecNotAvailable";
            description = @"No keychain is not available. You may need to restart your computer.";
            break;
        case errSecDuplicateItem:
            codeName = @"errSecDuplicateItem";
            description = @"That password already exists in the keychain.";
            break;
        case errSecItemNotFound:
            codeName = @"errSecItemNotFound";
            description = @"The item could not be found in the keychain.";
            break;
        case errSecInteractionNotAllowed:
            codeName = @"errSecInteractionNotAllowed";
            description = @"User interaction is not allowed.";
            break;
        case errSecDecode:
            codeName = @"errSecDecode";
            description = @"Unable to decode the provided data.";
            break;
        case errSecAuthFailed:
            codeName = @"errSecAuthFailed";
            description = @"The username or password you entered is not correct.";
            break;
        case -34018:
            codeName = @"-34018";
            description = @"Shared Keychain entitlements might be incorrect. Cf. http://stackoverflow.com/questions/20344255/secitemadd-and-secitemcopymatching-returns-error-code-34018-errsecmissingentit";
            break;
        default:
            codeName = @(statusCode).stringValue;
            description = @"Other keychain error.";
            break;
    }

    return [NSError errorWithDomain:MYCErrorDomain
                               code:statusCode
                           userInfo:@{NSLocalizedDescriptionKey:
                                          [NSString stringWithFormat:@"%@ (%@)",
                                           description, codeName]}];
}


+ (BOOL) isPasscodeSet {

    BOOL apiAvailable = (kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly != NULL);

    if (!apiAvailable) return NO;

    OSStatus status;

    // delete the item to resolve some entitlements and security issues when running from Xcode debugger
    {
        NSDictionary *query = @{
                                (__bridge id)kSecClass:  (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecAttrService: @"LocalDeviceServices",
                                (__bridge id)kSecAttrAccount: @"NoAccount"
                                };

        status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status == errSecSuccess || status == errSecItemNotFound) {
            // okay
        } else {
            MYCError(@"MYCUnlockedWallet: failed to delete isPasscodeSet probe: %@", [self errorForOSStatus:status]);
            // interesting.
        }
    }

    // From http://pastebin.com/T9YwEjnL
    NSData* secret = [@"Device has passcode set?" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{
                                 (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                 (__bridge id)kSecAttrService: @"LocalDeviceServices",
                                 (__bridge id)kSecAttrAccount: @"NoAccount",
                                 (__bridge id)kSecValueData: secret,
                                 (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
                                 };

    // Original code claimed to check if the item was already on the keychain
    // but in reality you can't add duplicates so this will fail with errSecDuplicateItem
    // if the item is already on the keychain (which could throw off our check if
    // kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly was not set)

    status = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
    if (status == errSecSuccess) { // item added okay, passcode has been set
        NSDictionary *query = @{
                                (__bridge id)kSecClass:  (__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecAttrService: @"LocalDeviceServices",
                                (__bridge id)kSecAttrAccount: @"NoAccount"
                                };
        
        status = SecItemDelete((__bridge CFDictionaryRef)query);

        if (status != errSecSuccess) {
            MYCError(@"MYCUnlockedWallet: status after deleting isPasscodeSet probe after successful creation: %@", [self errorForOSStatus:status]);
        }
        return YES;
    }

    MYCError(@"MYCUnlockedWallet: status after setting isPasscodeSet probe (errSecDecode is expected when passcode is not set): %@", [self errorForOSStatus:status]);
    
    // errSecDecode seems to be the error thrown on a device with no passcode set
    if (status == errSecDecode) {
        return NO;
    }
    
    return NO;
}


@end
