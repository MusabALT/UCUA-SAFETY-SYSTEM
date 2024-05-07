import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ucua_staging/features/user_auth/firebase_auth_implemantation/firebase_auth_services.dart';
import 'package:ucua_staging/features/user_auth/screens/pages/loginPage.dart';
import 'package:ucua_staging/features/user_auth/screens/widgets/form_container_widget.dart';
import 'package:ucua_staging/global_common/toast.dart';

class SignUp extends StatefulWidget {
  const SignUp({Key? key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool showProgress = false;
  bool visible = false;

  final _formkey = GlobalKey<FormState>();
  final FirebaseAuthService _auth = FirebaseAuthService();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  final TextEditingController _staffIDController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isSigningUp = false;

  var options = ['Select Your Role','Employee', 'Safety Department','Admin'];
  var _currentItemSelected = "Select Your Role";
  var role = "Select Your Role";

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNoController.dispose();
    _staffIDController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Sign Up",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: 30,
              ),
              FormContainerWidget(
                controller: _firstNameController,
                hintText: "First Name",
                isPasswordField: false,
              ),
              const SizedBox(
                height: 10,
              ),
              FormContainerWidget(
                controller: _lastNameController,
                hintText: "Last Name",
                isPasswordField: false,
              ),
              const SizedBox(
                height: 10,
              ),
              FormContainerWidget(
                controller: _phoneNoController,
                hintText: "Phone Number",
                isPasswordField: false,
              ),
              const SizedBox(
                height: 10,
              ),
              FormContainerWidget(
                controller: _staffIDController,
                hintText: "Staff ID",
                isPasswordField: false,
              ),
              const SizedBox(
                height: 10,
              ),
              FormContainerWidget(
                controller: _emailController,
                hintText: "Email",
                isPasswordField: false,
              ),
              const SizedBox(
                height: 10,
              ),
              FormContainerWidget(
                controller: _passwordController,
                hintText: "Password",
                isPasswordField: true,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Role: ",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  DropdownButton<String>(
                    dropdownColor: Color.fromARGB(255, 197, 210, 248),
                    isDense: true,
                    isExpanded: false,
                    iconEnabledColor: Colors.black45,
                    focusColor: Colors.black45,
                    items: options.map((String dropDownStringItem) {
                      return DropdownMenuItem<String>(
                        value: dropDownStringItem,
                        child: Text(
                          dropDownStringItem,
                          style: TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValueSelected) {
                      setState(() {
                        _currentItemSelected = newValueSelected!;
                        role = newValueSelected;
                      });
                    },
                    value: _currentItemSelected,
                  ),
                ],
              ),
              const SizedBox(
                height: 30,
              ),
              GestureDetector(
                onTap: _signUp,
                child: Container(
                  width: double.infinity,
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 33, 82, 243),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: isSigningUp
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  const SizedBox(
                    width: 5,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                          (route) => false);
                    },
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color.fromARGB(255, 33, 82, 243),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _signUp() async {
    setState(() {
      isSigningUp = true;
    });

    String firstName = _firstNameController.text;
    String lastName = _lastNameController.text;
    String phoneNo = _phoneNoController.text;
    String staffID = _staffIDController.text;
    String email = _emailController.text;
    String password = _passwordController.text;

    User? user = await _auth.signUpWithEmailAndPassword(email, password);

    setState(() {
      isSigningUp = false;
    });

    if (user != null) {
      FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
      CollectionReference usersRef = firebaseFirestore.collection('users');

      await usersRef.doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'phoneNo': phoneNo,
        'staffID': staffID,
        'email': email,
        'role': role, // Add role to Firestore
      });

      showToast(message: "User is successfully created");
      Navigator.pushNamed(context, "/login");
    } else {
      showToast(message: "Some error happened");
    }
  }
}
