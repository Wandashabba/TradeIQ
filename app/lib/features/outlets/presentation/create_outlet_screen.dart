import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../territories/data/territories_repository.dart';
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

  /// The chosen territory's **code**, which is what `Outlet.territoryId`
  /// stores. Held as a selection rather than typed text: this was a free field
  /// defaulted to 'gauteng-north', and it invited exactly the mistake it got —
  /// a store filed under the territory's *name* while the column wanted its
  /// code, leaving the outlet absent from every territory-scoped view with no
  /// error to explain it.
  String? _territoryCode;

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
    setState(() {
      _locating = true;
      _locationError = null;
    });
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
      await ref
          .read(outletsRepositoryProvider)
          .createOutlet(
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            channelType: _channelCtrl.text.trim(),
            lat: _lat!,
            lng: _lng!,
            territoryId: _territoryCode!,
          );
      ref.invalidate(outletsListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create store: $e')));
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
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Getting your location...'),
                          ],
                        )
                      : _locationError != null
                      ? Row(
                          children: [
                            const Icon(Icons.location_off, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            TextButton(
                              onPressed: _fetchLocation,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store Code',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _channelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Channel Type (e.g. supermarket)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // Names on screen, codes on the wire. A manager knows the store is
              // in "Gauteng North"; nobody memorises that its code is
              // 'gauteng-north' — still less '2773u'.
              ref
                  .watch(territoriesListProvider)
                  .when(
                    loading: () => const InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Territory',
                        border: OutlineInputBorder(),
                      ),
                      child: Text('Loading territories…'),
                    ),
                    error: (err, _) => InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Territory',
                        border: OutlineInputBorder(),
                        errorText: 'Could not load territories',
                      ),
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(territoriesListProvider),
                        child: const Text('Retry'),
                      ),
                    ),
                    data: (territories) => territories.isEmpty
                        // Better than an empty dropdown that looks broken: the
                        // outlet genuinely cannot be filed until a territory
                        // exists, and this says who can fix it.
                        ? const InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Territory',
                              border: OutlineInputBorder(),
                              errorText:
                                  'No territories yet — create one under Territories first',
                            ),
                            child: SizedBox.shrink(),
                          )
                        : DropdownButtonFormField<String>(
                            key: const ValueKey<String>('territory-picker'),
                            initialValue: _territoryCode,
                            decoration: const InputDecoration(
                              labelText: 'Territory',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final t in territories)
                                DropdownMenuItem<String>(
                                  value: t.code,
                                  child: Text(t.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _territoryCode = value),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                  ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Store'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
