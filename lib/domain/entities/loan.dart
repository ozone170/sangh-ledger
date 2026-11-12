class Loan {
  final String id;
  final String organizationId;
  final String memberId;
  final String loanCode;
  final int principalPaise;
  final int monthlyInterestBps; // 100 bps = 1%
  final String calculationMethod;
  final int dayCountBasis;
  final DateTime issueDate;
  final int? durationMonths;
  final DateTime? firstRepaymentDate;
  final String status; // Draft, Active, Partially Repaid, Closed, Restructured, Cancelled
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Loan({
    required this.id,
    required this.organizationId,
    required this.memberId,
    required this.loanCode,
    required this.principalPaise,
    this.monthlyInterestBps = 100,
    this.calculationMethod = 'reducing_balance',
    this.dayCountBasis = 365,
    required this.issueDate,
    this.durationMonths,
    this.firstRepaymentDate,
    this.status = 'Draft',
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'organization_id': organizationId,
        'member_id': memberId,
        'loan_code': loanCode,
        'principal_paise': principalPaise,
        'monthly_interest_bps': monthlyInterestBps,
        'calculation_method': calculationMethod,
        'day_count_basis': dayCountBasis,
        'issue_date': issueDate.toIso8601String(),
        'duration_months': durationMonths,
        'first_repayment_date': firstRepaymentDate?.toIso8601String(),
        'status': status,
        'remarks': remarks,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Loan.fromMap(Map<String, dynamic> map) => Loan(
        id: map['id'] as String,
        organizationId: map['organization_id'] as String,
        memberId: map['member_id'] as String,
        loanCode: map['loan_code'] as String,
        principalPaise: map['principal_paise'] as int,
        monthlyInterestBps: map['monthly_interest_bps'] as int? ?? 100,
        calculationMethod: map['calculation_method'] as String? ?? 'reducing_balance',
        dayCountBasis: map['day_count_basis'] as int? ?? 365,
        issueDate: DateTime.parse(map['issue_date'] as String),
        durationMonths: map['duration_months'] as int?,
        firstRepaymentDate: map['first_repayment_date'] != null
            ? DateTime.parse(map['first_repayment_date'] as String)
            : null,
        status: map['status'] as String? ?? 'Draft',
        remarks: map['remarks'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
