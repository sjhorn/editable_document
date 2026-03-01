/// A drop-in replacement for Flutter's EditableText with full block-level
/// document model support.
///
/// `EditableDocument` is to block documents what `EditableText` is to
/// single-field text.
library editable_document;

export 'src/model/attribution.dart';
export 'src/model/attributed_text.dart';
export 'src/model/code_block_node.dart';
export 'src/model/composer_preferences.dart';
export 'src/model/document.dart';
export 'src/model/document_change_event.dart';
export 'src/model/document_editing_controller.dart';
export 'src/model/document_node.dart';
export 'src/model/document_position.dart';
export 'src/model/document_selection.dart';
export 'src/model/edit_command.dart';
export 'src/model/edit_context.dart';
export 'src/model/edit_listener.dart';
export 'src/model/edit_reaction.dart';
export 'src/model/edit_request.dart';
export 'src/model/editor.dart';
export 'src/model/horizontal_rule_node.dart';
export 'src/model/image_node.dart';
export 'src/model/list_item_node.dart';
export 'src/model/mutable_document.dart';
export 'src/model/node_position.dart';
export 'src/model/paragraph_node.dart';
export 'src/model/text_node.dart';
export 'src/model/undoable_editor.dart';
export 'src/rendering/render_document_block.dart';
export 'src/rendering/render_text_block.dart';
export 'src/rendering/render_paragraph_block.dart';
export 'src/rendering/render_list_item_block.dart';
export 'src/rendering/render_image_block.dart';
export 'src/rendering/render_code_block.dart';
export 'src/rendering/render_horizontal_rule_block.dart';
export 'src/rendering/render_document_layout.dart';
export 'src/rendering/document_caret_painter.dart';
export 'src/rendering/document_selection_painter.dart';
export 'src/services/document_ime_serializer.dart';
export 'src/services/document_ime_input_client.dart';
export 'src/services/document_keyboard_handler.dart';
export 'src/widgets/component_builder.dart';
export 'src/widgets/document_field.dart';
export 'src/widgets/document_layout.dart';
export 'src/widgets/editable_document.dart';
