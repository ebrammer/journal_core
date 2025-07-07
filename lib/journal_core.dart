// journal_core/lib/journal_core.dart
library journal_core;

// Export editor logic
export 'src/editor/journal_editor_controller.dart';
export 'src/editor/editor_globals.dart';

// Export block types
export 'src/blocks/prayer_block.dart';
export 'src/blocks/scripture_block.dart';
export 'src/blocks/tag_picker_block.dart';
export 'src/blocks/divider_block.dart';
export 'src/blocks/date_block.dart';
export 'src/blocks/spacer_block.dart';
export 'src/blocks/metadata_block.dart';
// Export models
export 'src/models/block_model.dart';
export 'src/models/styled_span.dart';
export 'src/models/journal.dart';
export 'src/models/block_type_constants.dart';

// Export toolbar
export 'src/toolbar/toolbar.dart';

// Export utilities
export 'src/utils/delta_utils.dart';
export 'src/utils/selection_utils.dart';
export 'src/utils/focus_helpers.dart';
export 'src/utils/content_utils.dart';
export 'src/utils/logging.dart';

// Export widgets
export 'src/widgets/editor_widget.dart';
export 'src/widgets/reorderable_editor.dart';

// Export extensions
export 'src/extensions/context_extensions.dart';
