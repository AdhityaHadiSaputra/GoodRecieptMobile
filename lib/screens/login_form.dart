import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metrox_po/main_layout.dart';
import 'package:metrox_po/screens/button.dart';
import 'package:metrox_po/utils/storage.dart';

import '../api_service.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({Key? key}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ApiService apiService = ApiService();
  final StorageService storageService = StorageService.instance;

  var isObsecure = true.obs;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
         controller: usernameController,
          validator: (val) => val == "" ? "Please Write Email" : null,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.email,
              color: Colors.black,
           ),
            hintText: "Email...",
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: const BorderSide(
                                              color: Colors.white60
                                          )
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: const BorderSide(
                                              color: Colors.white60
                                          )
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: const BorderSide(
                                              color: Colors.white60
                                          )
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: const BorderSide(
                                              color: Colors.white60
                                          )
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6
                                      ),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                  ),

                                  const SizedBox(height: 18 ),
                                  Obx(
                                        ()=> TextFormField(
                                      controller: passwordController,
                                      obscureText: isObsecure.value,
                                      validator: (val) => val == "" ? "Please Write Password" : null,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                          Icons.vpn_key_sharp,
                                          color: Colors.black,
                                        ),
                                        suffixIcon: Obx(
                                                ()=> GestureDetector(
                                              onTap: (){
                                                isObsecure.value = !isObsecure.value;
                                              },
                                              child: Icon(
                                                isObsecure.value ? Icons.visibility_off : Icons.visibility,
                                                color: Colors.black,
                                              ),
                                            )
                                        ),
                                        hintText: "Password...",
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            borderSide: const BorderSide(
                                                color: Colors.white60
                                            )
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            borderSide: const BorderSide(
                                                color: Colors.white60
                                            )
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            borderSide: const BorderSide(
                                                color: Colors.white60
                                            )
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(30),
                                            borderSide: const BorderSide(
                                                color: Colors.white60
                                            )
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6
                                        ),
                                        fillColor: Colors.white,
                                        filled: true,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 18 ),
          SizedBox(height: 24.0),
          Button(
            width: double.infinity,
            title: 'Sign In',
            onPressed: () async {
              String USERID = usernameController.text;
              String USERPASSWORD = passwordController.text;

              try {
                Map<String, dynamic> result =
                    await apiService.loginUser(USERID, USERPASSWORD);
                result['USERID'] = USERID;
                result['USERPASSWORD'] = USERPASSWORD;

                if (result['code'] == "1") {
                  storageService.save(StorageKeys.USER, result);
                  showSuccess("User successfully logged in");
                } else {
                  showError("Login failed. Please check your credentials.");
                }
              } catch (error) {
                print('Error: $error');
                showError("An error occurred during login.");
              }
            },
            disable: false,
          ),
        ],
      ),
    );
  }

  void showSuccess(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Success!"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainLayout()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Error"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
