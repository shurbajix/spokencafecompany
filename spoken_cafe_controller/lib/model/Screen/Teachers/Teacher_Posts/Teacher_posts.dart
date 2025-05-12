import 'package:flutter/material.dart';

class Teacher_Posts extends StatefulWidget {
  const Teacher_Posts({super.key});

  @override
  State<Teacher_Posts> createState() => _Teacher_PostsState();
}

class _Teacher_PostsState extends State<Teacher_Posts> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 18 / 14,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'this is like a post and for tests',
                  style: TextStyle(fontSize: 30),
                ),
                Image.asset('assets/images/spken_cafe.png'),

                TextButton.icon(
                  onPressed: () {},
                  label: Text(
                    'Downlaod video and images',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
