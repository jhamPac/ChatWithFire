//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Photos
import UIKit
import Firebase
import GoogleMobileAds

/**
 * AdMob ad unit IDs are not currently stored inside the google-services.plist file. Developers
 * using AdMob can store them as custom values in another plist, or simply use constants. Note that
 * these ad units are configured to return only test ads, and should not be used outside this sample.
 */
let kBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

@objc(FCViewController)
class FCViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
    UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  // Instance variables
  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var sendButton: UIButton!
  var ref: FIRDatabaseReference!
  var messages = [FIRDataSnapshot]()
  var msglength: NSNumber = 10
  private var _refHandle: FIRDatabaseHandle!

  var storageRef: FIRStorageReference!
  var remoteConfig: FIRRemoteConfig!

  @IBOutlet weak var banner: GADBannerView!
  @IBOutlet weak var clientTable: UITableView!


  override func viewDidLoad()
  {
    super.viewDidLoad()
    
    ref = FIRDatabase.database().reference()
    self.clientTable.registerClass(UITableViewCell.self, forCellReuseIdentifier: "tableViewCell")

    configureDatabase()
    configureStorage()
    configureRemoteConfig()
    fetchConfig()
    loadAd()
    logViewLoaded()
  }
    
    override func viewWillDisappear(animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        self.ref.removeObserverWithHandle(_refHandle)
    }

  deinit
  {
    
  }

  func configureDatabase()
  {
    ref = FIRDatabase.database().reference()
    _refHandle = self.ref.child("messages").observeEventType(.ChildAdded, withBlock: { [unowned self] (snapshot) -> Void in
        self.messages.append(snapshot)
        self.clientTable.insertRowsAtIndexPaths([NSIndexPath(forRow: self.messages.count - 1, inSection: 0 )], withRowAnimation: .Automatic)
        })
  }

  func configureStorage()
  {
    storageRef = FIRStorage.storage().referenceForURL("gs://friendlychat-32be4.appspot.com")
  }

  func configureRemoteConfig()
  {
    
  }

  func fetchConfig()
  {
    
  }

  @IBAction func didPressFreshConfig(sender: AnyObject) {
    fetchConfig()
  }

  @IBAction func didSendMessage(sender: UIButton) {
    textFieldShouldReturn(textField)
  }

  @IBAction func didPressCrash(sender: AnyObject) {
    fatalError()
  }

  func logViewLoaded() {
  }

  func loadAd() {
  }

  func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
  {
    guard let text = textField.text else { return true }
    let newLength = text.utf16.count + string.utf16.count - range.length
    return newLength <= self.msglength.integerValue // Bool
    
  }
    
  // UITableViewDataSource protocol methods
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    return messages.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
  {
    // Dequeue cell
    let cell: UITableViewCell! = self.clientTable.dequeueReusableCellWithIdentifier("tableViewCell", forIndexPath: indexPath)
    let messageSnapShot: FIRDataSnapshot! = self.messages[indexPath.row]
    let message = messageSnapShot.value as! [String: String]
    let name = message[Constants.MessageFields.name] as String!
    
    if let imageUrl = message[Constants.MessageFields.imageUrl]
    {
        // the image is in FIRStorage
        if imageUrl.hasPrefix("gs://")
        {
            FIRStorage.storage().referenceForURL(imageUrl).dataWithMaxSize(INT64_MAX) { (data, error) -> Void in
                if let error = error
                {
                    print("Error downloading image \(error)")
                    return
                }
                
                cell.imageView?.image = UIImage(data: data!)
            }
        }
        // the image may be on the phone but no gs:// in front of it
        else if let url = NSURL(string: imageUrl), data = NSData(contentsOfURL: url)
        {
            cell.imageView?.image = UIImage(data: data)
        }
        
        // either way its an image so the text is sent by
        cell.textLabel?.text = "sent by: \(name)"
    }
    // this means its not an image but instead a text
    else
    {
        let text = message[Constants.MessageFields.text] as String!
        cell.textLabel?.text = "\(name): \(text)"
        cell.imageView?.image = UIImage(named: "ic_account_circle")
        
        if let photoUrl = message[Constants.MessageFields.photoUrl], url = NSURL(string: photoUrl), data = NSData(contentsOfURL: url)
        {
            cell.imageView?.image = UIImage(data: data)
        }
        
    }
    
    return cell
  }

  // UITextViewDelegate protocol methods
  func textFieldShouldReturn(textField: UITextField) -> Bool
  {
    let data = [Constants.MessageFields.text: textField.text! as String]
    sendMessage(data)
    return true
  }

  func sendMessage(data: [String: String])
  {
    var mdata = data
    mdata[Constants.MessageFields.name] = AppState.sharedInstance.displayName
    if let photoUrl = AppState.sharedInstance.photoUrl
    {
      mdata[Constants.MessageFields.photoUrl] = photoUrl.absoluteString
    }
    
    self.ref.child("messages").childByAutoId().setValue(mdata)
    self.textField.text = ""
  }

  // MARK: - Image Picker

  @IBAction func didTapAddPhoto(sender: AnyObject)
  {
    let picker = UIImagePickerController()
    picker.delegate = self
    if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera))
    {
      picker.sourceType = .Camera
    }
    else
    {
      picker.sourceType = .PhotoLibrary
    }

    presentViewController(picker, animated: true, completion:nil)
  }

  func imagePickerController(picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [String : AnyObject])
  {
    picker.dismissViewControllerAnimated(true, completion:nil)
    
    
    let referenceUrl = info[UIImagePickerControllerReferenceURL] as! NSURL
    let assets = PHAsset.fetchAssetsWithALAssetURLs([referenceUrl], options: nil)
    let asset = assets.firstObject
    
    asset?.requestContentEditingInputWithOptions(nil, completionHandler: { [unowned self] (contentEditingInput, info) -> Void in
    let imageFile = contentEditingInput?.fullSizeImageURL
    
    // build up a file string
    let userID = FIRAuth.auth()?.currentUser?.uid
    let timeStamp = Int(NSDate.timeIntervalSinceReferenceDate() * 1000)
    let component = referenceUrl.lastPathComponent!
    let filePath = "\(userID!)/\(timeStamp)/\(component)"
            
    print(filePath)
            
    let metadata = FIRStorageMetadata()
            
    metadata.contentType = "image/jpeg"
            
    self.storageRef.child(filePath).putFile(imageFile!, metadata: metadata) { [unowned self] (metadata, error) -> Void in
        if let error = error
        {
            print("Error uploading: \(error.description)")
            return
        }
            print(self.storageRef.child((metadata?.path!)!).description)
            self.sendMessage([Constants.MessageFields.imageUrl: self.storageRef.child((metadata?.path)!).description])
        }
    })
        
  }

  func imagePickerControllerDidCancel(picker: UIImagePickerController) {
    picker.dismissViewControllerAnimated(true, completion:nil)
  }

  @IBAction func signOut(sender: UIButton)
  {
    
    do
    {
        try FIRAuth.auth()?.signOut()
        AppState.sharedInstance.signedIn = false
        performSegueWithIdentifier(Constants.Segues.FpToSignIn, sender: nil)
    }
    catch let signoutError as NSError
    {
        print("Error signing out \(signoutError.localizedDescription)")
    }
  }

  func showAlert(title:String, message:String)
  {
    dispatch_async(dispatch_get_main_queue()) {
        let alert = UIAlertController(title: title,
            message: message, preferredStyle: .Alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Destructive, handler: nil)
        alert.addAction(dismissAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
  }

}
