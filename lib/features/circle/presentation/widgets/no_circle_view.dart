import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/circle_provider.dart';

class NoCircleView extends ConsumerStatefulWidget {
  const NoCircleView({super.key});

  @override
  ConsumerState<NoCircleView> createState() => _NoCircleViewState();
}

class _NoCircleViewState extends ConsumerState<NoCircleView> {
  final _createNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _formKeyCreate = GlobalKey<FormState>();
  final _formKeyJoin = GlobalKey<FormState>();

  @override
  void dispose() {
    _createNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _createCircle() {
    if (_formKeyCreate.currentState!.validate()) {
      // Usamos ref.read para llamar a una función del notifier.
      ref.read(circleProvider.notifier).createCircle(_createNameController.text.trim());
    }
  }

  void _joinCircle() {
    if (_formKeyJoin.currentState!.validate()) {
      ref.read(circleProvider.notifier).joinCircle(_joinCodeController.text.trim().toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sección para crear un círculo
          Text('Create a New Circle', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Form(
            key: _formKeyCreate,
            child: TextFormField(
              controller: _createNameController,
              decoration: const InputDecoration(
                labelText: 'Circle Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _createCircle,
            child: const Text('Create'),
          ),

          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 48),

          // Sección para unirse a un círculo
          Text('Join an Existing Circle', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Form(
            key: _formKeyJoin,
            child: TextFormField(
              controller: _joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Invitation Code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) => value!.isEmpty ? 'Please enter a code' : null,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _joinCircle,
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
