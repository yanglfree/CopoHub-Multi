import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class BranchTagPickerBottomSheet extends StatefulWidget {
  const BranchTagPickerBottomSheet({
    super.key,
    required this.branches,
    required this.tags,
    required this.initialRef,
  });

  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> tags;
  final String initialRef;

  /// Returns `(selectedName, sourceRef, isCreate)`.
  static Future<(String, String, bool)?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> branches,
    required List<Map<String, dynamic>> tags,
    required String initialRef,
  }) {
    return showModalBottomSheet<(String, String, bool)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BranchTagPickerBottomSheet(
        branches: branches,
        tags: tags,
        initialRef: initialRef,
      ),
    );
  }

  @override
  State<BranchTagPickerBottomSheet> createState() =>
      _BranchTagPickerBottomSheetState();
}

class _BranchTagPickerBottomSheetState
    extends State<BranchTagPickerBottomSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  late String _selectedSourceRef;

  @override
  void initState() {
    super.initState();
    _selectedSourceRef = widget.initialRef;
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSourcePicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(l10n.sourceBranch,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              itemCount: widget.branches.length,
              itemBuilder: (context, i) {
                final name = widget.branches[i]['name'] as String? ?? '';
                return ListTile(
                  dense: true,
                  title: Text(name),
                  leading: const Icon(Icons.fork_right, size: 18),
                  trailing: name == _selectedSourceRef
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(context, name),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedSourceRef = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final filteredBranches = widget.branches.where((b) {
      final name = b['name'] as String? ?? '';
      return name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final filteredTags = widget.tags.where((t) {
      final name = t['name'] as String? ?? '';
      return name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final exactMatchBranch = widget.branches.any((b) => b['name'] == _query);
    final showCreateOption = _query.isNotEmpty && !exactMatchBranch;

    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.switchBranchOrTag,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchOrCreateBranch,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            TabBar(
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              tabs: [
                Tab(text: '${l10n.branches} (${widget.branches.length})'),
                Tab(text: '${l10n.tags} (${widget.tags.length})'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  // Branches tab
                  CustomScrollView(
                    controller: controller,
                    slivers: [
                      if (showCreateOption)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.source,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _showSourcePicker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cs.outline),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.fork_right, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(_selectedSourceRef,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                        ),
                                        const Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.add, size: 18),
                                    label:
                                        Text('${l10n.createBranch}: $_query'),
                                    onPressed: () => Navigator.pop(context,
                                        (_query, _selectedSourceRef, true)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (showCreateOption)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(),
                          ),
                        ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final name =
                                filteredBranches[i]['name'] as String? ?? '';
                            final selected = name == widget.initialRef;
                            return ListTile(
                              dense: true,
                              title: Text(name),
                              leading: const Icon(Icons.fork_right, size: 18),
                              trailing: selected
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : null,
                              onTap: () =>
                                  Navigator.pop(context, (name, name, false)),
                            );
                          },
                          childCount: filteredBranches.length,
                        ),
                      ),
                    ],
                  ),
                  // Tags tab
                  ListView.builder(
                    controller: controller,
                    itemCount: filteredTags.length,
                    itemBuilder: (context, i) {
                      final name = filteredTags[i]['name'] as String? ?? '';
                      final selected = name == widget.initialRef;
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        leading:
                            const Icon(Icons.local_offer_outlined, size: 18),
                        trailing: selected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, (name, name, false)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
