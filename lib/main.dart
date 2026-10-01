import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: Ruta360App()));
}

// ==========================================
// MODELOS (Fase 8: Comunidades)
// ==========================================
class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
  });

  factory CommunityModel.fromMap(Map<String, dynamic> map, String id) {
    return CommunityModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': createdAt,
    };
  }
}

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Usuario',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': createdAt,
    };
  }
}

// ==========================================
// REPOSITORIO Y PROVIDERS
// ==========================================
class FirestoreCommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CommunityModel>> getCommunities() {
    return _firestore.collection('communities').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CommunityModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<PostModel>> getPosts(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}

final communityRepoProvider = Provider((ref) => FirestoreCommunityRepository());

final communitiesStreamProvider = StreamProvider<List<CommunityModel>>((ref) {
  return ref.watch(communityRepoProvider).getCommunities();
});

final postsStreamProvider = StreamProvider.family<List<PostModel>, String>((ref, communityId) {
  return ref.watch(communityRepoProvider).getPosts(communityId);
});

// ==========================================
// PANTALLAS Y ENRUTADOR
// ==========================================
final _router = GoRouter(
  initialLocation: '/communities',
  routes: [
    GoRoute(
      path: '/communities',
      builder: (context, state) => const CommunitiesScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return CommunityDetailScreen(communityId: id);
          },
        ),
      ],
    ),
  ],
);

class Ruta360App extends StatelessWidget {
  const Ruta360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ruta360',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: _router,
    );
  }
}

class CommunitiesScreen extends ConsumerWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(communitiesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Comunidades Ruta360')),
      body: communitiesAsync.when(
        data: (communities) {
          if (communities.isEmpty) {
            return const Center(child: Text('No hay comunidades disponibles.'));
          }
          return ListView.builder(
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              return ListTile(
                title: Text(community.name),
                subtitle: Text(community.description),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.push('/communities/${community.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class CommunityDetailScreen extends ConsumerWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsStreamProvider(communityId));

    return Scaffold(
      appBar: AppBar(title: const Text('Muro de la Comunidad')),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(child: Text('No hay publicaciones aún.'));
          }
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(post.authorName),
                  subtitle: Text(post.text),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
