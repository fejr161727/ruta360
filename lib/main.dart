import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const Ruta360App());
}

class Ruta360App extends StatelessWidget {
  const Ruta360App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruta360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const Center(child: Text('Inicio')),
    const Center(child: Text('Explorar')),
    const Center(child: Text('Registrar')),
    const CommunitiesScreen(),
    const Center(child: Text('Perfil')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explorar'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Registrar'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Comunidades'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ==========================================
// PANTALLA DE COMUNIDADES Y MURO DE PUBLICACIONES
// ==========================================

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({Key? key}) : super(key: key);

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateCommunityDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Crear Nueva Comunidad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Grupo',
                  hintText: 'Ej. Ciclistas del Norte',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Describe el propósito de esta comunidad...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final userId = _auth.currentUser?.uid;
                if (userId != null && nameController.text.trim().isNotEmpty) {
                  await _firestore.collection('communities').add({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'createdBy': userId,
                    'createdAt': FieldValue.serverTimestamp(),
                    'members': [userId],
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidades'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Mis Grupos'),
            Tab(icon: Icon(Icons.explore), text: 'Explorar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCommunitiesTab(),
          _buildExploreCommunitiesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCommunityDialog,
        icon: const Icon(Icons.add),
        label: const Text('Crear Grupo'),
      ),
    );
  }

  Widget _buildMyCommunitiesTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Inicia sesión para ver tus comunidades.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('communities')
          .where('members', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Aún no te has unido a ninguna comunidad.'),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final communityId = docs[index].id;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.groups),
                ),
                title: Text(data['name'] ?? 'Comunidad'),
                subtitle: Text(
                  data['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityFeedScreen(
                        communityId: communityId,
                        communityName: data['name'] ?? 'Comunidad',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExploreCommunitiesTab() {
    final userId = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('communities').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay comunidades disponibles.'));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final communityId = docs[index].id;
            final List members = data['members'] ?? [];
            final bool isMember = userId != null && members.contains(userId);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.public),
                ),
                title: Text(data['name'] ?? 'Comunidad'),
                subtitle: Text('${members.length} miembros'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    if (userId == null) return;
                    if (isMember) {
                      await _firestore.collection('communities').doc(communityId).update({
                        'members': FieldValue.arrayRemove([userId]),
                      });
                    } else {
                      await _firestore.collection('communities').doc(communityId).update({
                        'members': FieldValue.arrayUnion([userId]),
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMember ? Colors.grey : Theme.of(context).primaryColor,
                  ),
                  child: Text(isMember ? 'Salir' : 'Unirse'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CommunityFeedScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityFeedScreen({
    Key? key,
    required this.communityId,
    required this.communityName,
  }) : super(key: key);

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final TextEditingController _postController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _publishPost() async {
    final text = _postController.text.trim();
    final userId = _auth.currentUser?.uid;

    if (text.isNotEmpty && userId != null) {
      await _firestore.collection('community_posts').add({
        'communityId': widget.communityId,
        'authorId': userId,
        'content': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _postController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.communityName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje para el muro...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _publishPost,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('community_posts')
                  .where('communityId', isEqualTo: widget.communityId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No hay publicaciones en esta comunidad aún.'),
                  );
                }

                final posts = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(post['content'] ?? ''),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
