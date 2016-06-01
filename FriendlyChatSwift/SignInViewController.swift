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

import UIKit
import Firebase

@objc(SignInViewController)
class SignInViewController: UIViewController
{
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    }

    override func viewDidAppear(animated: Bool)
    {
        if let user = FIRAuth.auth()?.currentUser
        {
            self.signedIn(user)
        }
    }

    @IBAction func didTapSignIn(sender: AnyObject)
    {
        let email = emailField.text!
        let password = passwordField.text!
        
        FIRAuth.auth()?.signInWithEmail(email, password: password) { [unowned self] (user, error) -> Void in
            if let error = error
            {
                print(error.localizedDescription)
                return
            }
            
            self.signedIn(user!)
        }
    }

    @IBAction func didTapSignUp(sender: AnyObject)
    {
        let email = emailField.text!
        let password = passwordField.text!
        
        FIRAuth.auth()?.createUserWithEmail(email, password: password) { [unowned self] (user, error) -> Void in
            if let error = error
            {
                print(error.localizedDescription)
                return
            }
            
            self.setDisplayName(user!)
        }
    }

    func setDisplayName(user: FIRUser)
    {
        let changeRequest = user.profileChangeRequest()
        changeRequest.displayName = user.email!.componentsSeparatedByString("@")[0]
        
        changeRequest.commitChangesWithCompletion() { [unowned self] (error) -> Void in
            if let error = error
            {
                print(error.localizedDescription)
                return
            }
            
            self.signedIn(FIRAuth.auth()?.currentUser)
        }
        
    }

    @IBAction func didRequestPasswordReset(sender: AnyObject)
    {
        let prompt = UIAlertController(title: nil, message: "Email:", preferredStyle: .Alert)
        let okAction = UIAlertAction(title: "OK", style: .Default) { (action) -> Void in
            let userInput = prompt.textFields![0].text
            if userInput!.isEmpty
            {
                return
            }
            
            FIRAuth.auth()?.sendPasswordResetWithEmail(userInput!) { (error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
            }

        }
        
        prompt.addTextFieldWithConfigurationHandler(nil)
        prompt.addAction(okAction)
        presentViewController(prompt, animated: true, completion: nil)
    }

    func signedIn(user: FIRUser?)
    {
        MeasurementHelper.sendLoginEvent()
        AppState.sharedInstance.displayName = user?.displayName ?? user?.email
        AppState.sharedInstance.photoUrl = user?.photoURL
        AppState.sharedInstance.signedIn = true
        NSNotificationCenter.defaultCenter().postNotificationName(Constants.NotificationKeys.SignedIn, object: nil, userInfo: nil)
        performSegueWithIdentifier(Constants.Segues.SignInToFp, sender: nil)
    }
}
