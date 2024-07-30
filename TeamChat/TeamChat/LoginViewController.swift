//
//  LoginViewController.swift
//  TeamChat
//
//  Created by Meenal Mishra on 26/07/24.
//

import UIKit

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    var activeTextField: UITextField?
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var textFieldView: UIView!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var hostTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.setGradientVerticalBackground()
        mainView.layer.cornerRadius = 20
        mainView.layer.shadowColor = UIColor.black.cgColor
        mainView.layer.shadowOpacity = 0.1
        mainView.layer.shadowOffset = CGSize(width: 0, height: 5)
        mainView.layer.shadowRadius = 10
        textFieldView.layer.cornerRadius = 15
        textFieldView.layer.borderWidth = 1
        textFieldView.layer.borderColor = UIColor.lightGray.cgColor
        styleTextField(emailTextField)
        styleTextField(passwordTextField)
        styleTextField(hostTextField)
        emailTextField.delegate = self
        passwordTextField.delegate = self
        hostTextField.delegate = self
        submitButton.layer.cornerRadius = 10
        submitButton.setTitle("Submit", for: .normal)
        applyGradientToButton(button: submitButton)
        
        //        emailTextField.text = "testuser@mofa.onice.io"
        //        passwordTextField.text = "Password123456"
        //        hostTextField.text = "mofa.onice.io"
        
        if let token = getTokenFromKeychain() {
            navigateToSecondScreen(token: token)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        if let keyboardSize = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardSize.height
            let bottomSpace = view.frame.height - (activeTextField?.frame.origin.y ?? 0) - (activeTextField?.frame.height ?? 0)
            let offset = keyboardHeight - bottomSpace + 310
            if offset > 0 {
                view.frame.origin.y = -offset
            }
        }
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        view.frame.origin.y = 0
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        activeTextField = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @IBAction func submitButtonTapped(_ sender: UIButton) {
        if validateFields() {
            submitCalled(username:self.emailTextField.text ?? "",password:self.passwordTextField.text ?? "", host: self.hostTextField.text ?? "")
        }
    }
    
    func submitCalled(username:String,password:String,host:String) {
        let requestBody = [
            "username": username,
            "password": password
        ]
        Task {
            if let data = await APIManager.shared.performPostAsyncRequest(urlString: "https://\(host)/teamchatapi/iwauthentication.login.plain", requestBody: requestBody) {
                do {
                    
                    if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],  let token = jsonObject["token"] as? String {
                        saveTokenToKeychain(token: token)
                        navigateToSecondScreen(token: token)
                    } else {
                        print("Error: Unable to parse JSON response.")
                    }
                } catch {
                    print("Error: JSON parsing failed with error \(error.localizedDescription)")
                }
            } else {
                print("Login failed.")
            }
        }
    }
    
    func navigateToSecondScreen(token : String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let secondVC = storyboard.instantiateViewController(withIdentifier: "ChannelScreenViewController") as? ChannelScreenViewController {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            secondVC.token = token
            secondVC.managedContext = appDelegate.managedContext
            self.navigationController?.pushViewController(secondVC, animated: true)
        }
    }
    
    func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == noErr, let retrievedData = dataTypeRef as? Data,
           let token = String(data: retrievedData, encoding: .utf8) {
            return token
        } else {
            return nil
        }
    }
    
    func saveTokenToKeychain(token: String) {
        let tokenData = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: tokenData
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func validateFields() -> Bool {
        guard let email = emailTextField.text, !email.isEmpty else {
            showAlert(message: "Email cannot be empty.")
            return false
        }
        
        guard let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Password cannot be empty.")
            return false
        }
        
        guard let host = hostTextField.text, !host.isEmpty else {
            showAlert(message: "Host cannot be empty.")
            return false
        }
        
        if !isValidEmail(email) {
            showAlert(message: "Please enter a valid email address.")
            return false
        }
        
        if password.count < 6 {
            showAlert(message: "Password must be at least 6 characters long.")
            return false
        }
        
        return true
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Oops..", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func styleTextField(_ textField: UITextField) {
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.layer.masksToBounds = true
        textField.setLeftPaddingPoints(10)
    }
    
    func applyGradientToButton(button: UIButton) {
        let colorTop = Constants.init().secondColor
        let colorBottom = Constants.init().firstColor
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colorTop, colorBottom]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = button.layer.cornerRadius
        gradientLayer.frame = button.bounds
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.setTitleColor(.white, for: .normal)
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
}

extension UIView
{
    func setGradientVerticalBackground() {
        let colorTop = Constants.init().secondColor
        let colorBottom = Constants.init().firstColor
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colorTop, colorBottom]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = self.bounds
        self.layer.insertSublayer(gradientLayer, at:0)
    }
    
    func setGradientHorizontalBackground() {
        let colorTop = Constants.init().secondColor
        let colorBottom = Constants.init().firstColor
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colorTop, colorBottom]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.frame = self.bounds
        self.layer.insertSublayer(gradientLayer, at:0)
    }
}
