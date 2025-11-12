

import SwiftUI
// import GoogleSignIn
// import GoogleSignInSwift

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Moodiary")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    Task {
                        let success = await authViewModel.signIn(withEmail: email, password: password)
                        if !success {
                            self.showError = true
                        }
                    }
                }) {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .alert("Login Failed", isPresented: $showError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Please check your email and password and try again.")
                }

                
                
                NavigationLink("Don't have an account? Sign Up", destination: RegistrationView())
                
                Spacer()
            }
            .padding()
            .navigationTitle("Login")
        }
    }
}
