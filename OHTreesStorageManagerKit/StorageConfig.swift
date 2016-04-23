//
//  StorageConfig.swift
//  DrinkUp
//
//  Created by Paul Bunting on 11/27/15.
//  Copyright © 2015 Paul Bunting. All rights reserved.
//

import Foundation

//import AppConfig
import OHTreesAppConfig

public typealias StorageState = (storageOption: StorageConfig.Storage, accountDidChange: Bool, cloudAvailable: Bool)

public class StorageConfig {

    public static var callingApplication: UIApplication?
    
    private var _appConfig: AppConfig = AppConfig.sharedAppConfig

    private struct Defaults {
        static let storageOptionKey = "AppConfiguration.Defaults.storageOptionKey"
        static let storedUbiquityIdentityToken = "AppConfiguration.Defaults.storedUbiquityIdentityToken"
    }

    // Provide singleton access
    //
    public class var sharedStorageConfig: StorageConfig {
        struct Singleton {
            static let sharedStorageConfig = StorageConfig(app: StorageConfig.callingApplication)
        }
        
        return Singleton.sharedStorageConfig
    }

    public var isCloudAvailable: Bool {
        let result = NSFileManager.defaultManager().ubiquityIdentityToken != nil
        NSLog("isCloudAvailable \(result)")
        return result
    }
    
    #if os(iOS)
    public var storageState: StorageState {
        return (storageOption, hasAccountChanged(), isCloudAvailable)
    }
    
    public enum Storage: Int {
        case NotSet = 0, Local, Cloud
    }

    public var storageOption: Storage {
        get {
            let value = _appConfig.get(Defaults.storageOptionKey) as! Int
//            let value = applicationUserDefaults.integerForKey(Defaults.storageOptionKey)
    
            return Storage(rawValue: value)!
        }
        
        set {
            _appConfig.set(Defaults.storageOptionKey, value: newValue.rawValue)
//            applicationUserDefaults.setInteger(newValue.rawValue, forKey: Defaults.storageOptionKey)
        }
    }

    public func hasAccountChanged() -> Bool {
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

    #endif
    
    private var application: UIApplication?
    
    public init(app: UIApplication?) {
        application = app
        
        // Observe changes to the user's iCloud account status (account changed, logged out, etc...).
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleUbiquityIdentityDidChangeNotification:", name: NSUbiquityIdentityDidChangeNotification, object: nil)
        
//        if StorageConfig.sharedStorageConfig.isCloudAvailable {
        
            /**
             A private, local queue used to ensure serialized access to Cloud containers during application
             startup.
             */
            let appDelegateQueue = dispatch_queue_create("com.100trees.OHTStorageManagerKit.CloudStorageScheme", DISPATCH_QUEUE_SERIAL)
            
            /*
            Ensure the app sandbox is extended to include the default container. Perform this action on the
            `AppDelegate`'s serial queue so that actions dependent on the extension always follow it.
            */
            dispatch_async(appDelegateQueue) {
                // The initial call extends the sandbox. No need to capture the URL.
                NSFileManager.defaultManager().URLForUbiquityContainerIdentifier(nil)
                
                return
            }
//        }
        
        StorageConfig.sharedStorageConfig.registerForNotification()

    }
    
    public func registerForNotification() {
        #if os(iOS)
            // Register for cloudkit subscription notifications
            let notificationSettings = UIUserNotificationSettings(forTypes: UIUserNotificationType.Alert, categories: nil)
            if let app = application {
                app.registerUserNotificationSettings(notificationSettings)
                app.registerForRemoteNotifications()
            }
        #endif
    }
    
    @objc func handleUbiquityIdentityDidChangeNotification(notification: NSNotification) {
        setupUserStoragePreferences()
    }
    
    func setupUserStoragePreferences() {
        let storageState = StorageConfig.sharedStorageConfig.storageState
        
        /*
        Check to see if the account has changed since the last time the method was called. If it has, let
        the user know that their documents have changed. If they've already chosen local storage (i.e. not
        iCloud), don't notify them since there's no impact.
        */
        if storageState.accountDidChange && storageState.storageOption == .Cloud {
            notifyUserOfAccountChange(storageState)
            // Return early. State resolution will take place after the user acknowledges the change.
            return
        }
        
        resolveStateForUserStorageState(storageState)
    }
    
    func resolveStateForUserStorageState(storageState: StorageState) {
        if storageState.cloudAvailable {
            if storageState.storageOption == .NotSet  || (storageState.storageOption == .Local && storageState.accountDidChange) {
                // iCloud is available, but we need to ask the user what they prefer.
                promptUserForStorageOption()
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
                StorageConfig.sharedStorageConfig.storageOption = .NotSet
            }
            //            StorageSchemeHandler.configureAppWithStorageOption(accountChanged: storageState.accountDidChange, updateSettings: false, schm: storageState.storageOption)
        }
    }
    
    
    func notifyUserOfAccountChange(storageState: StorageState) {
        if !storageState.cloudAvailable {
            // Establish a user friendly base "no-data" to continue from
            // TODO
        }
        
        let title = NSLocalizedString("Sign Out of iCloud", comment: "")
        let message = NSLocalizedString("You have signed out of the iCloud account previously used to store documents. Sign back in with that account to access those documents.", comment: "")
        let okActionTitle = NSLocalizedString("OK", comment: "")
        
        let signedOutController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let action = UIAlertAction(title: okActionTitle, style: .Cancel) { _ in
            self.resolveStateForUserStorageState(storageState)
        }
        signedOutController.addAction(action)
        
        dispatch_async(dispatch_get_main_queue()) {
            // Display the signed out alert view
            if let app = self.application {
                app.delegate!.window!!.rootViewController!.presentViewController(signedOutController, animated: true, completion: nil)
            }
        }
    }
    
    func promptUserForSettingsSource() {
        let title = NSLocalizedString("Update Settings with those in iCloud", comment: "")
        let message = NSLocalizedString("Do you want to change the application settings to those in iCloud or update iCloud with the current settings?", comment: "")
        let keepSettingsActionTitle = NSLocalizedString("Keep current", comment: "")
        let updateSettingsActionTitle = NSLocalizedString("Update from iCloud", comment: "")
        
        let settingsController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let keepOption = UIAlertAction(title: keepSettingsActionTitle, style: .Default) { cloudAction in
            StorageConfig.sharedStorageConfig.storageOption = .Cloud
            
            dispatch_async(dispatch_get_main_queue()) {
                //                StorageSchemeHandler.configureAppWithStorageOption(accountChanged: true, updateSettings: true, schm: .Cloud) {
                // Switch to local storage
                NSLog("configureAppWithStorageOption completion Switch to cloud storage keeping current settings")
                //                }
            }
        }
        settingsController.addAction(keepOption)
        
        let updateOption = UIAlertAction(title: updateSettingsActionTitle, style: .Default) { cloudAction in
            StorageConfig.sharedStorageConfig.storageOption = .Cloud
            dispatch_async(dispatch_get_main_queue()) {
                //                StorageSchemeHandler.configureAppWithStorageOption(accountChanged: true, updateSettings: false, schm: .Cloud) {
                // Switch to iCloud storage
                NSLog("configureAppWithStorageOption completion Switch to iCloud storage update settings from iCloud")
                //                }
            }
        }
        settingsController.addAction(updateOption)
        
        dispatch_async(dispatch_get_main_queue()) {
            if let app = self.application {
                app.delegate!.window!!.rootViewController!.presentViewController(settingsController, animated: true, completion: nil)
            }
        }
    }
    
    func promptUserForStorageOption() {
        let title = NSLocalizedString("Choose Storage Option", comment: "")
        let message = NSLocalizedString("Do you want to store documents in iCloud or only on this device?", comment: "")
        let localOnlyActionTitle = NSLocalizedString("Local Only", comment: "")
        let cloudActionTitle = NSLocalizedString("iCloud", comment: "")
        
        let storageController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        let localOption = UIAlertAction(title: localOnlyActionTitle, style: .Default) { localAction in
            StorageConfig.sharedStorageConfig.storageOption = .Local
            
            dispatch_async(dispatch_get_main_queue()) {
                //                StorageSchemeHandler.configureAppWithStorageOption(accountChanged: true, updateSettings: false, schm: .Local) {
                // Switch to local storage
                NSLog("configureAppWithStorageOption completion Switch to local storage")
                //                }
            }
        }
        storageController.addAction(localOption)
        
        let cloudOption = UIAlertAction(title: cloudActionTitle, style: .Default) { cloudAction in
            StorageConfig.sharedStorageConfig.storageOption = .Cloud
            dispatch_async(dispatch_get_main_queue()) {
                // Switch to iCloud storage
                NSLog("configureAppWithStorageOption completion Switch to iCloud storage")
                self.promptUserForSettingsSource()
            }
        }
        storageController.addAction(cloudOption)
        
        dispatch_async(dispatch_get_main_queue()) {
            if let app = self.application {
                app.delegate!.window!!.rootViewController!.presentViewController(storageController, animated: true, completion: nil)
            }
        }
    }

}