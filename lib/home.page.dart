import 'package:flutter/material.dart';
import 'package:tp33/screens/Cards.view.dart';
import 'package:tp33/screens/Home.view.dart';
import 'package:tp33/screens/Login.view.dart';
import 'package:tp33/screens/Profil.view.dart';
class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currIndex=1;

  List<Widget> pages=[
    Homeview(), Loginview(), CardsView(isActive: false),ProfileView(),

  ];

  void changePage( int selectedIndex){
    setState(
      (){
currIndex=selectedIndex;
pages[2] = CardsView(isActive: selectedIndex == 2);
      }
    );
    

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 17, 65, 91),
        title: Text("Applicatiom multitaches",
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
        ),
      ),
      ),
      body: SafeArea(
        child: Padding(padding: EdgeInsets.all(16.0),
      child:IndexedStack(index: currIndex,children: pages)),),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currIndex,
        backgroundColor: const Color.fromARGB(255, 112, 181, 63),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.black,
        items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.login), label: "Login"),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: "Cards"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
      onTap: changePage
      
      )
    );
  }
}
