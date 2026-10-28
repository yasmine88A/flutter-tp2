import 'package:flutter/material.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            backgroundImage: AssetImage('images/profil.jpg'),
            radius: 80,
          ),
          const SizedBox(height: 10),
          const Text(
            'shruti@gmail.com',
            style: TextStyle(
              color: Color.fromARGB(255, 60, 40, 63),
              fontSize: 20,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // Ajouter ici l'action du bouton.
            },
            style: ElevatedButton.styleFrom(
              elevation: 30,
              foregroundColor: Colors.white,
              backgroundColor: const Color.fromARGB(255, 116, 79, 123),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5.0),
                side: const BorderSide(color: Colors.black),
              ),
            ),
            child: const Text('Modifier le profil'),
          ),
        ],
      ),
    );
  }
}