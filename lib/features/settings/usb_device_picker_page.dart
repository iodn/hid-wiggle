import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/models/usb_device.dart';
import '../../core/services/usb_ids_providers.dart';
import '../../core/widgets/app_card.dart';

enum SearchMode { vendor, product }

class UsbDevicePickerPage extends ConsumerStatefulWidget {
  const UsbDevicePickerPage({super.key});

  @override
  ConsumerState<UsbDevicePickerPage> createState() => _UsbDevicePickerPageState();
}

class _UsbDevicePickerPageState extends ConsumerState<UsbDevicePickerPage> {
  String _query = '';
  SearchMode _mode = SearchMode.product;
  UsbVendor? _selectedVendor;
  bool _isLoading = false;
  List<UsbVendor> _vendors = [];
  List<UsbProduct> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(usbIdsRepositoryProvider);
      final results = await repo.searchVendors(_query);
      if (mounted) {
        setState(() {
          _vendors = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vendors: $e')),
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(usbIdsRepositoryProvider);
      final results = await repo.searchProducts(
        _query,
        vendorId: _selectedVendor?.vid,
      );
      if (mounted) {
        setState(() {
          _products = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  void _switchMode(SearchMode mode) {
    setState(() {
      _mode = mode;
      _query = '';
      _selectedVendor = null;
      _vendors = [];
      _products = [];
    });
    if (mode == SearchMode.vendor) {
      _loadVendors();
    } else {
      _loadProducts();
    }
  }

  void _onSearch(String value) {
    setState(() => _query = value);
    if (_mode == SearchMode.vendor || _selectedVendor != null) {
      if (_selectedVendor != null) {
        _loadProducts();
      } else {
        _loadVendors();
      }
    } else {
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Device Picker'),
      ),
      body: Column(
        children: [
          if (_selectedVendor == null)
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: SegmentedButton<SearchMode>(
                segments: const [
                  ButtonSegment(
                    value: SearchMode.product,
                    label: Text('Search Products'),
                    icon: Icon(Icons.usb),
                  ),
                  ButtonSegment(
                    value: SearchMode.vendor,
                    label: Text('Browse by Vendor'),
                    icon: Icon(Icons.business),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (Set<SearchMode> selection) {
                  _switchMode(selection.first);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: _getSearchHint(),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          if (_selectedVendor != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.business),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedVendor!.name,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            _selectedVendor!.vidHex,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear vendor',
                      onPressed: () {
                        setState(() {
                          _selectedVendor = null;
                          _query = '';
                        });
                        if (_mode == SearchMode.vendor) {
                          _loadVendors();
                        } else {
                          _loadProducts();
                        }
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedVendor != null) const SizedBox(height: AppTokens.spaceMd),
          Expanded(
            child: _buildContent(theme),
          ),
        ],
      ),
    );
  }

  String _getSearchHint() {
    if (_selectedVendor != null) {
      return 'Search products in ${_selectedVendor!.name}…';
    }
    if (_mode == SearchMode.vendor) {
      return 'Search vendors (e.g., Logitech)…';
    }
    return 'Search products (e.g., Wireless Mouse)…';
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mode == SearchMode.vendor && _selectedVendor == null) {
      return _buildVendorList(theme);
    }

    return _buildProductList(theme);
  }

  Widget _buildVendorList(ThemeData theme) {
    if (_vendors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Text(
            _query.isEmpty
                ? 'No vendors found.'
                : 'No vendors match "$_query".',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      itemCount: _vendors.length,
      itemBuilder: (context, i) {
        final v = _vendors[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
          child: AppCard(
            onTap: () {
              setState(() {
                _selectedVendor = v;
                _query = '';
              });
              _loadProducts();
            },
            child: Row(
              children: [
                const Icon(Icons.business),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: theme.textTheme.titleSmall),
                      Text(v.vidHex, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductList(ThemeData theme) {
    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Text(
            _query.isEmpty
                ? (_selectedVendor != null
                    ? 'No products found for ${_selectedVendor!.name}.'
                    : 'No products found.')
                : 'No products match "$_query".',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      itemCount: _products.length,
      itemBuilder: (context, i) {
        final p = _products[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
          child: AppCard(
            onTap: () => Navigator.of(context).pop(p),
            child: Row(
              children: [
                const Icon(Icons.usb),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      if (p.vendorName != null)
                        Text(
                          p.vendorName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(p.vidPidLabel, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_outline),
              ],
            ),
          ),
        );
      },
    );
  }
}
