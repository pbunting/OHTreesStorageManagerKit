//
//  CloudKitStorageConfig.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 11/27/15.
//  Copyright © 2015 Paul Bunting. All rights reserved.
//

import Foundation

import OHTreesAppConfig


public protocol CloudKitStorageSelectionDelegate {
    func selectICloud(useDecision: (Bool) -> Void)
    
    func icloudAccountChanged() -> Void
    func iCloudUnavailable() -> Void
}

public typealias CloudKitStorageState = (storageOption: CloudKitStorageConfig.CloudKitStorage, accountDidChange: Bool, cloudAvailable: Bool)

public class CloudKitStorageConfig {

    public var stateDelegate: CloudKitStorageSelectionDelegate?

    public var storageState: CloudKitStorageState {
        return (storageOption, hasAccountChanged(), isCloudAvailable)
    }
    
    public enum CloudKitStorage: Int {
        case NotSet = 0, Local, Cloud
    }
    
    public var storageOption: CloudKitStorage {
        get {
            let value = _appConfig.get(Defaults.storageOptionKey) as! Int
            return CloudKitStorage(rawValue: value)!
        }
        
        set {
            _appConfig.set(Defaults.storageOptionKey, value: newValue.rawValue)
        }
    }

    public var isCloudAvailable: Bool {
        let result = NSFileManager.defaultManager().ubiquityIdentityToken != nil
        NSLog("isCloudAvailable \(result)")
        return result
    }

    
    private var _appConfig: AppConfig = AppConfig.sharedAppConfig

    private struct Defaults {
        static let storageOptionKey = "AppConfiguration.Defaults.storageOptionKey"
        static let storedUbiquityIdentityToken = "AppConfiguration.Defaults.storedUbiquityIdentityToken"
    }
    
    

    private func hasAccountChanged() -> Bool {
        var hasChanged = false
        
        let currentToken: protocol<NSCoding, NSCopying, NSObjectProtocol>? = NSFileManager.defaultManager().ubiquityIdentityToken
        let storedToken: protocol<NSCoding, NSCopying, NSObjectProtocol>? = storedUbiquityIdentityToken
        
        let currentTokenNilStoredNonNil = currentToken == nil && storedToken != nil
        let storedTokenNilCurrentNonNil = currentToken != nil && storedToken == nil
        
        // Compare the tokens.
        let currentNotEqualStored = currentToken != nil && storedToken != nil && !currentToken!.isEqual(storedToken!)
        
        if currentTokenNilStoredNonNil || storedTokenNilCurrentNonNil || currentNotEqualStored {
            persistAccount()
            
            hasChanged = true
        }
        
        return hasChanged
    }
    
    private var storedUbiquityIdentityToken: protocol<NSCoding, NSCopying, NSObjectProtocol>? {
        var storedToken: protocol<NSCoding, NSCopying, NSObjectProtocol>?
        
        // Determine if the logged in iCloud account has changed since the user last launched the app.
        let archivedObject: AnyObject? = _appConfig.get(Defaults.storedUbiquityIdentityToken)
//    applicationUserDefaults.objectForKey(Defaults.storedUbiquityIdentityToken)
    
        if let ubiquityIdentityTokenArchive = archivedObject as? NSData,
            let archivedObject = NSKeyedUnarchiver.unarchiveObjectWithData(ubiquityIdentityTokenArchive) as? protocol<NSCoding, NSCopying, NSObjectProtocol> {
                storedToken = archivedObject
        }
        
        return storedToken
    }

    private func persistAccount() {
//        let defaults = applicationUserDefaults
    
        if let token = NSFileManager.defaultManager().ubiquityIdentityToken {
            let ubiquityIdentityTokenArchive = NSKeyedArchiver.archivedDataWithRootObject(token)
            
            _appConfig.set(Defaults.storedUbiquityIdentityToken, value:ubiquityIdentityTokenArchive)
        }
        else {
            _appConfig.remove(Defaults.storedUbiquityIdentityToken)
        }
    }

    
//    private var application: UIApplication?
    
    public init(app: UIApplication?) {
        // Observe changes to the user's iCloud account status (account changed, logged out, etc...).
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleUbiquityIdentityDidChangeNotification:", name: NSUbiquityIdentityDidChangeNotification, object: nil)
        
//        if StorageConfig.sharedStorageConfig.isCloudAvailable {
        
            /**
             A private, local queue used to ensure serialized access to Cloud containers during application
             startup.
             */
            let localQueue = dispatch_queue_create("com.100trees.OHTStorageManagerKit.CloudStorageScheme", DISPATCH_QUEUE_SERIAL)
            
            /*
            Ensure the app sandbox is extended to include the default container. Perform this action on the
            `AppDelegate`'s serial queue so that actions dependent on the extension always follow it.
            */
            dispatch_async(localQueue) {
                // The initial call extends the sandbox. No need to capture the URL.
                NSFileManager.defaultManager().URLForUbiquityContainerIdentifier(nil)
                
                return
            }
//        }
            // Register for cloudkit subscription notifications
            let notificationSettings = UIUserNotificationSettings(forTypes: UIUserNotificationType.Alert, categories: nil)
            if let application = app {
                application.registerUserNotificationSettings(notificationSettings)
                application.registerForRemoteNotifications()
            }
    }
    

    @objc func handleUbiquityIdentityDidChangeNotification(notification: NSNotification) {
        setupUserStoragePreferences()
    }
    
    func setupUserStoragePreferences() {
//        let storageState = CloudKitStorageConfig.sharedStorageConfig.storageState
        
        /*
        Check to see if the account has changed since the last time the method was called. If it has, let
        the user know that their documents have changed. If they've already chosen local storage (i.e. not
        iCloud), don't notify them since there's no impact.
        */
        if storageState.accountDidChange && storageState.storageOption == .Cloud {
            if let delegate = stateDelegate {
                delegate.icloudAccountChanged()
            }
//            notifyUserOfAccountChange(storageState)
            // Return early. State resolution will take place after the user acknowledges the change.
            return
        }
        
        resolveStateForUserStorageState(storageState)
    }
    
    func resolveStateForUserStorageState(storageState: CloudKitStorageState) {
        if storageState.cloudAvailable {
            if storageState.storageOption == .NotSet  || (storageState.storageOption == .Local && storageState.accountDidChange) {
                // iCloud is available, but we need to ask the user/application what they prefer.
                if let delegate = stateDelegate {
                    delegate.selectICloud( {(useIcloud: Bool) in
                        if (useIcloud) {
                            self.storageOption = .Cloud
                        } else {
                            self.storageOption = .Local
                        }
                    } )
                    //                promptUserForStorageOption()
                }
            }
            else {
                /*
                The user has already selected a specific storage option. Configure the app to use the
                chosen storage option
                */
                //                StorageSchemeHandler.configureAppWithStorageOption(accountChanged: storageState.accountDidChange, updateSettings: false, schm: storageState.storageOption)
            }
        }
        else {
            /*
            iCloud is not available, so we'll reset the storage option and configure the app.
            The next time that the user signs in with an iCloud account, he or she can change provide their
            desired storage option.
            */
            if storageState.storageOption != .NotSet {
                storageOption = .NotSet
                
                if let delegate = stateDelegate {
                    delegate.iCloudUnavailable()
                }
            }
            //            StorageSchemeHandler.configureAppWithStorageOption(accountChanged: storageState.accountDidChange, updateSettings: false, schm: storageState.storageOption)
        }
    }

}