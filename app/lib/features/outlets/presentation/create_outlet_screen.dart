import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/tiq_colors.dart';
import '../data/outlets_repository.dart';

class CreateOutletScreen extends ConsumerStatefulWidget {
  const CreateOutletScreen({super.key});

  @override
  ConsumerState<CreateOutletScreen> createState() => _CreateOutletScreenState();
}

class _CreateOutletScreenState extends ConsumerState<CreateOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _channelCtrl = TextEditingController();
  final _territoryCtrl = TextEditingController(text: 'gauteng-north');

  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _submitting = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() { _locating = true; _locationError = null; });
    final result = await ref.read(locationServiceProvider).getCurrentPosition();
    setState(() {
      _locating = false;
      if (result is LocationGranted) {
        _lat = result.lat;
        _lng = result.lng;
      } else if (result is LocationDenied) {
        _locationError = 'Location permission denied.';
      } else if (result is LocationError) {
        _locationError = (result).message;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available yet.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(outletsRepositoryProvider).createOutlet(
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        channelType: _channelCtrl.text.trim(),
        lat: _lat!,
        lng: _lng!,
        territoryId: _territoryCtrl.text.trim(),
      );
      ref.invalidate(outletsListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create store: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _channelCtrl.dispose();
    _territoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Store')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _locating
                      ? const Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Getting your location...'),
                        ])
                      : _locationError != null
                          ? Row(children: [
                              Icon(Icons.location_off, color: context.colors.crit),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_locationError!, style: TextStyle(color: context.colors.crit))),
                              TextButton(onPressed: _fetchLocation, child: const Text('Retry')),
                            ])
                          : Row(children: [
                              Icon(Icons.location_on, color: context.colors.good),
                              const SizedBox(width: 8),
                              Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
                            ]),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Store Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: 'Store Code', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _channelCtrl,
                decoration: const InputDecoration(labelText: 'Channel Type (e.g. supermarket)', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _territoryCtrl,
                decoration: const InputDecoration(labelText: 'Territory ID', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Store'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
