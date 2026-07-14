enum EmployeeStatus { active, onLeave, suspended, terminated, resigned }

enum SalaryType { monthly, daily, hourly }

class Employee {
  final String id;
  final String tenantId;
  final String branchId;
  final String? userId;
  final String employeeCode;
  final String name;
  final String? cnic;
  final String? phone;
  final String? email;
  final String? address;
  final String? designation;
  final String? department;
  final DateTime joiningDate;
  final DateTime? terminationDate;
  final SalaryType salaryType;
  final double baseSalary;
  final String? bankName;
  final String? bankAccountNumber;
  final String? emergencyContact;
  final String? emergencyPhone;
  final EmployeeStatus status;
  final String? notes;

  /// Display-only, from the embedded `branches(name)` join on load.
  final String? branchName;

  const Employee({
    required this.id,
    required this.tenantId,
    required this.branchId,
    this.userId,
    required this.employeeCode,
    required this.name,
    this.cnic,
    this.phone,
    this.email,
    this.address,
    this.designation,
    this.department,
    required this.joiningDate,
    this.terminationDate,
    required this.salaryType,
    required this.baseSalary,
    this.bankName,
    this.bankAccountNumber,
    this.emergencyContact,
    this.emergencyPhone,
    required this.status,
    this.notes,
    this.branchName,
  });

  bool get isActive => status == EmployeeStatus.active;
}
