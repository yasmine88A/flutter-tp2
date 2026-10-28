import 'package:flutter/material.dart';

class Loginview extends StatelessWidget {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
   Loginview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding:  EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical:50,
        ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center,children: [
        Text("Login",style: TextStyle(color: Colors.indigo,fontSize: 30,fontWeight: FontWeight.bold),),
        SizedBox(height: 25),
        TextField(
          controller: usernameController,
          decoration: InputDecoration(
            labelText: "Nom d'utilisateur",
            labelStyle: TextStyle(color: Colors.teal,fontSize: 25),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.indigo,width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.pink,width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
           
          ),
        ),
SizedBox(height: 25),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: "Mot de passe",
            labelStyle: TextStyle(color: Colors.teal,fontSize: 25),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.indigo,width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.pink,width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
           
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 198, 243, 33),
            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10))),
        
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.green,
                content: Text("Connexion de: ${usernameController.text} ... (simulation)"),
              )
            );
          }, child: Text("Se connecter",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 20),)),
         SizedBox(height: 30),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color.fromARGB(255, 244, 54, 212),
                  content: Text("Lien de réinitialisation envoyé ")));
              
            },
            child: Text("Mot de passe oublié ?",style: TextStyle(color: Colors.red,fontSize: 15,fontStyle: FontStyle.italic),)
          ),
        

      ],),
      )
      
        
      
    );
  }
}