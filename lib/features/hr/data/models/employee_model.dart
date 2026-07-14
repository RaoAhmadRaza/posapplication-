import '../../domain/entities/employee.dart';

class EmployeeModel {
  static Employee fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      userId: json['user_id'] as String?,
      employeeCode: json['employee_code'] as String,
      name: json['name'] as String,
      cnic: json['cnic'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      joiningDate: DateTime.parse(json['joining_date'] as String),
      terminationDate: json['termination_date'] == null
          ? null
          : DateTime.tryParse(json['termination_date'].toString()),
      salaryType: parseSalaryType(json['salary_type'] as String?),
      baseSalary: double.tryParse(json['base_salary'].toString()) ?? 0,
      bankName: json['bank_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      status: parseStatus(json['status'] as String?),
      notes: json['notes'] as String?,
      branchName:
          (json['branches'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  static String statusToDb(EmployeeStatus s) => switch (s) {
        EmployeeStatus.active => 'ACTIVE',
        EmployeeStatus.onLeave => 'ON_LEAVE',
        EmployeeStatus.suspended => 'SUSPENDED',
        EmployeeStatus.terminated => 'TERMINATED',
        EmployeeStatus.resigned => 'RESIGNED',
      };

  static EmployeeStatus parseStatus(String? s) =>
      switch ((s ?? 'ACTIVE').toUpperCase()) {
        'ACTIVE' => EmployeeStatus.active,
        'ON_LEAVE' => EmployeeStatus.onLeave,
        'SUSPENDED' => EmployeeStatus.suspended,
        'TERMINATED' => EmployeeStatus.terminated,
        'RESIGNED' => EmployeeStatus.resigned,
        _ => EmployeeStatus.active,
      };

  static String salaryTypeToDb(SalaryType t) => switch (t) {
        SalaryType.monthly => 'MONTHLY',
        SalaryType.daily => 'DAILY',
        SalaryType.hourly => 'HOURLY',
      };

  static SalaryType parseSalaryType(String? t) =>
      switch ((t ?? 'MONTHLY').toUpperCase()) {
        'MONTHLY' => SalaryType.monthly,
        'DAILY' => SalaryType.daily,
        'HOURLY' => SalaryType.hourly,
        _ => SalaryType.monthly,
      };
}
