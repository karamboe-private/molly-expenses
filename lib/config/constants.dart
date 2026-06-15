class AppConstants {
  static const String usersCollection = 'users';
  static const String accountsCollection = 'accounts';
  static const String membersSubcollection = 'members';
  static const String expensesSubcollection = 'expenses';
  static const String inviteCodesCollection = 'inviteCodes';

  static const String defaultBeneficiaryName = 'Molly';
  static const String defaultCurrency = 'NOK';

  static const List<String> expenseCategories = [
    'Groceries',
    'Transport',
    'Healthcare',
    'Clothing',
    'Activities',
    'Personal care',
    'Other',
  ];

  static const String roleOwner = 'owner';
  static const String roleAssistant = 'assistant';

  static const String statusDraft = 'draft';
  static const String statusConfirmed = 'confirmed';
}
