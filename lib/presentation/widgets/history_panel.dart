import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/detection_provider.dart';
import '../../data/models/detection_record.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DetectionProvider>(
      builder: (context, detectionProvider, child) {
        final records = detectionProvider.records;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              top: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              _PanelHeader(
                totalDetections: detectionProvider.totalDetections,
                onClearAll: records.isNotEmpty ? () => _clearAll(context, detectionProvider) : null,
              ),
              Expanded(
                child: records.isEmpty
                    ? _EmptyState()
                    : _DetectionList(records: records),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearAll(BuildContext context, DetectionProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Limpiar historial', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se eliminarán ${provider.totalDetections} registros. ¿Continuar?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar todo', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.clearAllRecords();
    }
  }
}

class _PanelHeader extends StatelessWidget {
  final int totalDetections;
  final VoidCallback? onClearAll;

  const _PanelHeader({required this.totalDetections, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'HISTORIAL',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalDetections',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onClearAll != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClearAll,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_sweep,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off, color: Colors.grey[600], size: 32),
          const SizedBox(height: 8),
          Text(
            'Esperando dorsales...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _DetectionList extends StatelessWidget {
  final List records;

  const _DetectionList({required this.records});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _DetectionItem(
          record: record,
          index: index,
          onEdit: () => _editDorsal(context, index, record),
          onDelete: () => _deleteRecord(context, index),
        );
      },
    );
  }

  void _editDorsal(BuildContext context, int index, DetectionRecord record) async {
    final controller = TextEditingController(text: record.dorsal);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Editar dorsal', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Dorsal',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.greenAccent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.greenAccent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty && context.mounted) {
      final provider = context.read<DetectionProvider>();
      await provider.updateRecord(index, controller.text.trim());
    }
    controller.dispose();
  }

  void _deleteRecord(BuildContext context, int index) async {
    final provider = context.read<DetectionProvider>();
    await provider.deleteRecord(index);
  }
}

class _DetectionItem extends StatelessWidget {
  final dynamic record;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DetectionItem({
    required this.record,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('${record.dorsal}_${record.formattedTime}_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Eliminar registro', style: TextStyle(color: Colors.white)),
            content: Text(
              '¿Eliminar dorsal ${record.dorsal}?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.dorsal,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward, color: Colors.grey[600], size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                record.formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit, color: Colors.grey[500], size: 16),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, color: Colors.grey[500], size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
