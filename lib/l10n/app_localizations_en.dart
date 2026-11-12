// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sangh Ledger';

  @override
  String get login => 'Login';

  @override
  String get loginToLedger => 'Login to Ledger';

  @override
  String get firstTimeSetup => 'First-Time Setup (Onboarding)';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get pin => 'PIN';

  @override
  String get enterPin => 'Enter 4-6 Digit PIN';

  @override
  String get biometricLogin => 'Use Fingerprint / Face Unlock';

  @override
  String get biometricPrompt => 'Scan fingerprint to access Sangh Ledger';

  @override
  String get homeTab => 'Home';

  @override
  String get membersTab => 'Members';

  @override
  String get savingsTab => 'Savings';

  @override
  String get loansTab => 'Loans';

  @override
  String get moreTab => 'More';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get cashInHand => 'Cash in Hand';

  @override
  String get bankBalance => 'Bank Balance';

  @override
  String get savingsLiabilities => 'Member Savings Liabilities';

  @override
  String get loanReceivables => 'Loan Principal Receivables';

  @override
  String get interestReceivables => 'Interest Receivables';

  @override
  String get interestIncome => 'Interest Income';

  @override
  String get members => 'Members';

  @override
  String get activeMembers => 'Active Members';

  @override
  String get inactiveMembers => 'Inactive Members';

  @override
  String get addMember => 'Add Member';

  @override
  String get editMember => 'Edit Member';

  @override
  String get memberDetails => 'Member Details';

  @override
  String get memberCode => 'Member Code';

  @override
  String get fullName => 'Full Name';

  @override
  String get phone => 'Phone Number';

  @override
  String get address => 'Address';

  @override
  String get savings => 'Savings';

  @override
  String get loans => 'Loans';

  @override
  String get transactions => 'Transactions';

  @override
  String get overview => 'Overview';

  @override
  String get deposit => 'Deposit';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get mode => 'Payment Mode';

  @override
  String get cash => 'Cash';

  @override
  String get bank => 'Bank';

  @override
  String get remarks => 'Remarks';

  @override
  String get issueLoan => 'Issue Loan';

  @override
  String get principalAmount => 'Principal Amount';

  @override
  String get interestRate => 'Monthly Interest Rate (%)';

  @override
  String get reducingBalance => 'Reducing Balance';

  @override
  String get repayment => 'Repayment';

  @override
  String get reports => 'Reports';

  @override
  String get settings => 'Settings';

  @override
  String get backup => 'Encrypted Backup';

  @override
  String get restore => 'Restore Backup';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get kannada => 'ಕನ್ನಡ';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get errorRequired => 'This field is required';

  @override
  String get errorMemberCap => 'Maximum limit of 100 active members reached';

  @override
  String get errorInsufficientBalance =>
      'Insufficient savings balance for withdrawal';

  @override
  String get errorOverpayment =>
      'Repayment exceeds total outstanding loan and interest';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptNumber => 'Receipt No';

  @override
  String get transactionId => 'Transaction ID';

  @override
  String get authorizedBy => 'Authorized Administrator';

  @override
  String get signature => 'Signature';

  @override
  String get trialBalance => 'Trial Balance';

  @override
  String get dayCashbook => 'Daily Cashbook';

  @override
  String get memberLedger => 'Member Ledger';

  @override
  String get auditLog => 'Audit Log';

  @override
  String get reversal => 'Reverse Transaction';

  @override
  String get reversalReason => 'Reversal Reason';

  @override
  String get disburseLoan => 'Disburse Loan';

  @override
  String get recordRepayment => 'Record Repayment';

  @override
  String get reverseDisbursement => 'Reverse Disbursement';

  @override
  String get reverseDisbursementConfirm =>
      'Are you sure you want to reverse this loan disbursement? A balanced reversal entry will be posted and the loan will revert to Draft.';

  @override
  String get outstandingLoanPrincipal => 'Outstanding Loan Principal';

  @override
  String get totalSavingsBalance => 'Total Savings Balance';

  @override
  String get repaymentHistory => 'Repayment History';

  @override
  String get noRepaymentsYet => 'No repayments recorded yet';

  @override
  String get loanDisbursedSuccess => 'Loan successfully disbursed!';

  @override
  String get disbursementReversedSuccess =>
      'Disbursement successfully reversed and ledger balanced!';
}
