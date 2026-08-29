enum AiExecutionLocation { local, cloud }

final class AiProviderDescriptor {
  const AiProviderDescriptor({
    required this.id,
    required this.location,
    required this.openAiCompatible,
    this.zeroDataRetention = false,
  });

  final String id;
  final AiExecutionLocation location;
  final bool openAiCompatible;
  final bool zeroDataRetention;
}

final class AiRequestAuthorization {
  const AiRequestAuthorization({
    required this.provider,
    required this.cloudDisclosureAccepted,
  });

  final AiProviderDescriptor provider;
  final bool cloudDisclosureAccepted;

  bool get maySendMessageContent {
    return provider.location == AiExecutionLocation.local ||
        cloudDisclosureAccepted;
  }
}

abstract interface class AiProvider {
  AiProviderDescriptor get descriptor;

  Stream<String> complete({
    required String prompt,
    required List<String> context,
  });
}
