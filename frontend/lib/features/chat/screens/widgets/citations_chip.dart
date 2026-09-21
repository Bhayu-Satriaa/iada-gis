import 'package:flutter/material.dart';

class CitationsChip extends StatelessWidget {
  final Map<String, dynamic> citation;

  const CitationsChip({
    super.key,
    required this.citation
  });

  @override
  Widget build(BuildContext context) {
    final String rawTitle = citation['source'] as String? ?? 'Sumber tidak diketahui';
    final String title = _formatSourceName(rawTitle);

    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 13, color: Colors.grey.shade700,),
              const SizedBox(width: 4,),
              Flexible(
                child: 
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500
                    ),
                  )
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatSourceName(String raw) {
    String name = raw.replaceAll(RegExp(r'\.(csv|xlsx|xls|pdf|shp)$'), '');
    name = name.replaceAll('-', ' ').replaceAll('_', ' ');
    return name;
  }
}