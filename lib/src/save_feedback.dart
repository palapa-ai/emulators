enum SaveFeedback {
  saving('Saving', '…'),
  saved('Saved', '✓'),
  failed('Save failed', '!');

  const SaveFeedback(this.label, this.symbol);

  final String label;
  final String symbol;
}
