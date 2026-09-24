import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';

class TaskBridgeSearchBar extends StatefulWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  const TaskBridgeSearchBar({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<TaskBridgeSearchBar> createState() => _TaskBridgeSearchBarState();
}

class _TaskBridgeSearchBarState extends State<TaskBridgeSearchBar> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 52,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused ? palette.primary : palette.border,
          width: _isFocused ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        onChanged: widget.onChanged,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: palette.text,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: palette.muted,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 22,
              color: _isFocused ? palette.primary : palette.muted,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 22,
            minHeight: 22,
          ),
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,

          suffixIcon:
              (widget.controller != null && widget.controller!.text.isNotEmpty)
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: palette.muted,
                  ),
                  onPressed: () {
                    widget.controller!.clear();
                    widget.onChanged?.call('');
                  },
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
        ),
      ),
    );
  }
}
