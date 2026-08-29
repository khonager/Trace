import 'package:flutter_test/flutter_test.dart';
import 'package:trace/features/ai/domain/ai_provider.dart';

void main() {
  test('local providers do not require a cloud disclosure', () {
    const authorization = AiRequestAuthorization(
      provider: AiProviderDescriptor(
        id: 'local',
        location: AiExecutionLocation.local,
        openAiCompatible: true,
      ),
      cloudDisclosureAccepted: false,
    );

    expect(authorization.maySendMessageContent, isTrue);
  });

  test('cloud providers require an explicit disclosure', () {
    const authorization = AiRequestAuthorization(
      provider: AiProviderDescriptor(
        id: 'openrouter',
        location: AiExecutionLocation.cloud,
        openAiCompatible: true,
        zeroDataRetention: true,
      ),
      cloudDisclosureAccepted: false,
    );

    expect(authorization.maySendMessageContent, isFalse);
  });
}
