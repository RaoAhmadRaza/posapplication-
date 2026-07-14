enum TemplateChannel { sms, email }

/// A tenant message template. For SMS, [body] is the message text and [subject]
/// is null. For email, [subject] is the subject and [body] holds body_html.
class MessageTemplate {
  final String? id;
  final TemplateChannel channel;
  final String templateCode;
  final String name;
  final String? subject;
  final String body;
  final String language;
  final bool isActive;

  const MessageTemplate({
    this.id,
    required this.channel,
    required this.templateCode,
    required this.name,
    this.subject,
    required this.body,
    this.language = 'en',
    this.isActive = true,
  });

  MessageTemplate copyWith({
    String? name,
    String? subject,
    String? body,
    String? language,
    bool? isActive,
  }) =>
      MessageTemplate(
        id: id,
        channel: channel,
        templateCode: templateCode,
        name: name ?? this.name,
        subject: subject ?? this.subject,
        body: body ?? this.body,
        language: language ?? this.language,
        isActive: isActive ?? this.isActive,
      );
}
