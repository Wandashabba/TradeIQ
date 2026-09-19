import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/lumen_glass.dart';
import '../../../core/theme/lumen_palette.dart';
import '../../../core/theme/tiq_colors.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_page_scaffold.dart';
import '../../../core/widgets/lumen_kit.dart';
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

  /// The coordinates that will actually be sent (#386).
  ///
  /// The device position seeds these and nothing more. It used to BE them:
  /// `getCurrentPosition()` was the only source an outlet's pin could have, so
  /// a manager onboarding forty stores from the depot on a Monday pinned forty
  /// stores to the depot car park — and until PATCH /outlets/:id existed, no
  /// screen in the product could correct a single one of them.
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

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
        // Seeded, not locked. A manager standing in the store keeps what the
        // phone found; one sitting at the depot types the real numbers over it.
        _latCtrl.text = result.lat.toString();
        _lngCtrl.text = result.lng.toString();
      } else if (result is LocationDenied) {
        _locationError = 'Location permission denied.';
      } else if (result is LocationError) {
        _locationError = (result).message;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // The typed fields are the source of truth now, not `_lat`/`_lng` — so a
    // store can be created with the right coordinates even when the phone
    // never got a fix, which is the whole point of the fields being editable.
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the store\'s coordinates.')),
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
            lat: lat,
            lng: lng,
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
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.colors.glass;
    final storeFields = <Widget>[
      TextFormField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Store Name',
          border: OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _codeCtrl,
        decoration: const InputDecoration(
          labelText: 'Store Code',
          border: OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _channelCtrl,
        decoration: const InputDecoration(
          labelText: 'Channel Type (e.g. supermarket)',
          border: OutlineInputBorder(),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                onPressed: () => ref.invalidate(territoriesListProvider),
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
      const SizedBox(height: 12),
      // Editable, seeded from the phone (#386). A manager who is not standing
      // in the store must be able to type where the store actually is, or the
      // pin is wrong the moment it is created and stays wrong forever.
      TextFormField(
        key: const ValueKey<String>('create-outlet-lat'),
        controller: _latCtrl,
        keyboardType:
            const TextInputType.numberWithOptions(signed: true, decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Latitude',
          helperText: 'Between -90 and 90. Johannesburg is about -26.2',
          border: OutlineInputBorder(),
        ),
        validator: (v) => _coordinate(v, 90, 'latitude'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey<String>('create-outlet-lng'),
        controller: _lngCtrl,
        keyboardType:
            const TextInputType.numberWithOptions(signed: true, decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Longitude',
          helperText: 'Between -180 and 180. Johannesburg is about 28.0',
          border: OutlineInputBorder(),
        ),
        validator: (v) => _coordinate(v, 180, 'longitude'),
      ),
      const SizedBox(height: 12)
    ];

    return GlassPageScaffold(
      title: const Text('Create Store'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: glass
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassLocation(
                      locating: _locating,
                      error: _locationError,
                      lat: _lat,
                      lng: _lng,
                      onRetry: _fetchLocation,
                    ),
                    const SizedBox(height: 14),
                    GlassPane(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Kicker('Store'),
                          const SizedBox(height: 12),
                          ...storeFields,
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassPrimaryButton(
                      label: 'Create Store',
                      busy: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                )
              : Column(
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Getting your location...'),
                                ],
                              )
                            : _locationError != null
                            ? Row(
                                children: [
                                  const Icon(
                                    Icons.location_off,
                                    color: Colors.red,
                                  ),
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
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...storeFields,
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

/// Where the store will be pinned, in glass. The fix is the store's geofence,
/// so it leads the form: a figure when it lands, and a failure that carries
/// its own words on an opaque crit wash (AA on its own) with the retry beside.
class _GlassLocation extends StatelessWidget {
  const _GlassLocation({
    required this.locating,
    required this.error,
    required this.lat,
    required this.lng,
    required this.onRetry,
  });

  final bool locating;
  final String? error;
  final double? lat;
  final double? lng;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lumen = context.lumen;
    final Widget status;
    if (locating) {
      status = Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Getting your location...',
            style: TextStyle(fontSize: 13, color: lumen.inkMuted),
          ),
        ],
      );
    } else if (error != null) {
      final crit = LumenStatus.crit.swatchOf(colors);
      status = Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: Color.alphaBlend(crit.tint, colors.surface1),
          borderRadius: BorderRadius.circular(LumenGlass.radiusIconTile),
          border: Border.all(color: crit.rim),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 18, color: crit.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: crit.ink,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    } else {
      final good = LumenStatus.good.swatchOf(colors);
      status = Row(
        children: [
          Icon(Icons.location_on, size: 18, color: good.ink),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
              style: LumenGlass.figure(size: 15, color: lumen.ink),
            ),
          ),
        ],
      );
    }
    return GlassPane(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [const Kicker('Location'), const SizedBox(height: 10), status],
      ),
    );
  }
}

/// A typed coordinate, or the reason it is not one.
String? _coordinate(String? value, double bound, String what) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Required';
  final parsed = double.tryParse(text);
  if (parsed == null) return 'Enter a number, e.g. -26.2041';
  if (parsed < -bound || parsed > bound) {
    return 'A $what is between -${bound.toInt()} and ${bound.toInt()}';
  }
  return null;
}
