// -*- mode: Swift -*-

// AUTOGENERATED BY glean_parser v7.2.1. DO NOT EDIT. DO NOT COMMIT.

#if canImport(Foundation)
    import Foundation
#endif

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


import Glean

// swiftlint:disable superfluous_disable_command
// swiftlint:disable nesting
// swiftlint:disable line_length
// swiftlint:disable identifier_name
// swiftlint:disable force_try

extension GleanMetrics {
    class GleanBuild {
        private init() {
            // Intentionally left private, no external user can instantiate a new global object.
        }

        public static let info = BuildInfo(buildDate: DateComponents(calendar: Calendar.current, timeZone: TimeZone(abbreviation: "UTC"), year: 2023, month: 7, day: 1, hour: 5, minute: 15, second: 4))
    }

    enum NimbusEvents {
        struct DisqualificationExtra: EventExtras {
            var branch: String?
            var enrollmentId: String?
            var experiment: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let branch = self.branch {
                    record["branch"] = String(branch)
                }
                if let enrollmentId = self.enrollmentId {
                    record["enrollment_id"] = String(enrollmentId)
                }
                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }

                return record
            }
        }

        struct EnrollFailedExtra: EventExtras {
            var branch: String?
            var experiment: String?
            var reason: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let branch = self.branch {
                    record["branch"] = String(branch)
                }
                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }
                if let reason = self.reason {
                    record["reason"] = String(reason)
                }

                return record
            }
        }

        struct EnrollmentExtra: EventExtras {
            var branch: String?
            var enrollmentId: String?
            var experiment: String?
            var experimentType: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let branch = self.branch {
                    record["branch"] = String(branch)
                }
                if let enrollmentId = self.enrollmentId {
                    record["enrollment_id"] = String(enrollmentId)
                }
                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }
                if let experimentType = self.experimentType {
                    record["experiment_type"] = String(experimentType)
                }

                return record
            }
        }

        struct ExposureExtra: EventExtras {
            var branch: String?
            var experiment: String?
            var featureId: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let branch = self.branch {
                    record["branch"] = String(branch)
                }
                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }
                if let featureId = self.featureId {
                    record["feature_id"] = String(featureId)
                }

                return record
            }
        }

        struct MalformedFeatureExtra: EventExtras {
            var branch: String?
            var experiment: String?
            var featureId: String?
            var partId: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let branch = self.branch {
                    record["branch"] = String(branch)
                }
                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }
                if let featureId = self.featureId {
                    record["feature_id"] = String(featureId)
                }
                if let partId = self.partId {
                    record["part_id"] = String(partId)
                }

                return record
            }
        }

        struct UnenrollFailedExtra: EventExtras {
            var experiment: String?
            var reason: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }
                if let reason = self.reason {
                    record["reason"] = String(reason)
                }

                return record
            }
        }

        struct UnenrollmentExtra: EventExtras {
            var branch: String?
            var enrollmentId: String?
            var experiment: String?
            var reason: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let branch = self.branch {
                    record["branch"] = String(branch)
                }
                if let enrollmentId = self.enrollmentId {
                    record["enrollment_id"] = String(enrollmentId)
                }
                if let experiment = self.experiment {
                    record["experiment"] = String(experiment)
                }
                if let reason = self.reason {
                    record["reason"] = String(reason)
                }

                return record
            }
        }

        /// Recorded when a user becomes ineligible to continue receiving the treatment for
        /// an enrolled experiment, for reasons such as the user opting out of the
        /// experiment or no longer matching targeting for the experiment.
        static let disqualification = EventMetricType<DisqualificationExtra>( // generated from nimbus_events.disqualification
            CommonMetricData(
                category: "nimbus_events",
                name: "disqualification",
                sendInPings: ["events"],
                lifetime: .ping,
                disabled: false
            )
            , ["branch", "enrollment_id", "experiment"]
        )

        /// Recorded when an enrollment fails, including the reason for the failure.
        static let enrollFailed = EventMetricType<EnrollFailedExtra>( // generated from nimbus_events.enroll_failed
            CommonMetricData(
                category: "nimbus_events",
                name: "enroll_failed",
                sendInPings: ["background-update", "events"],
                lifetime: .ping,
                disabled: false
            )
            , ["branch", "experiment", "reason"]
        )

        /// Recorded when a user has met the conditions and is first bucketed into an
        /// experiment (i.e. targeting matched and they were randomized into a bucket and
        /// branch of the experiment). Expected a maximum of once per experiment per user.
        static let enrollment = EventMetricType<EnrollmentExtra>( // generated from nimbus_events.enrollment
            CommonMetricData(
                category: "nimbus_events",
                name: "enrollment",
                sendInPings: ["events"],
                lifetime: .ping,
                disabled: false
            )
            , ["branch", "enrollment_id", "experiment", "experiment_type"]
        )

        /// Recorded when a user actually observes an experimental treatment, or would have
        /// observed an experimental treatment if they had been in a branch that would have
        /// shown one.
        static let exposure = EventMetricType<ExposureExtra>( // generated from nimbus_events.exposure
            CommonMetricData(
                category: "nimbus_events",
                name: "exposure",
                sendInPings: ["events"],
                lifetime: .ping,
                disabled: false
            )
            , ["branch", "experiment", "feature_id"]
        )

        /// Recorded when feature code detects a problem with some part of the feature
        /// configuration.
        static let malformedFeature = EventMetricType<MalformedFeatureExtra>( // generated from nimbus_events.malformed_feature
            CommonMetricData(
                category: "nimbus_events",
                name: "malformed_feature",
                sendInPings: ["events"],
                lifetime: .ping,
                disabled: false
            )
            , ["branch", "experiment", "feature_id", "part_id"]
        )

        /// Recorded when an unenrollment fails, including the reason for the failure.
        static let unenrollFailed = EventMetricType<UnenrollFailedExtra>( // generated from nimbus_events.unenroll_failed
            CommonMetricData(
                category: "nimbus_events",
                name: "unenroll_failed",
                sendInPings: ["background-update", "events"],
                lifetime: .ping,
                disabled: false
            )
            , ["experiment", "reason"]
        )

        /// Recorded when either telemetry is disabled, or the experiment has run for its
        /// designed duration (i.e. it is no longer present in the Nimbus Remote Settings
        /// collection)
        static let unenrollment = EventMetricType<UnenrollmentExtra>( // generated from nimbus_events.unenrollment
            CommonMetricData(
                category: "nimbus_events",
                name: "unenrollment",
                sendInPings: ["events"],
                lifetime: .ping,
                disabled: false
            )
            , ["branch", "enrollment_id", "experiment", "reason"]
        )

    }

    enum NimbusHealth {
        struct CacheNotReadyForFeatureExtra: EventExtras {
            var featureId: String?

            func toExtraRecord() -> [String: String] {
                var record = [String: String]()

                if let featureId = self.featureId {
                    record["feature_id"] = String(featureId)
                }

                return record
            }
        }

        /// Measure how long `applyPendingExperiments` takes.
        /// `applyPendingExperiments` uses disk I/O, and happens at
        /// startup, as part of the initialization sequence.
        static let applyPendingExperimentsTime = TimingDistributionMetricType( // generated from nimbus_health.apply_pending_experiments_time
            CommonMetricData(
                category: "nimbus_health",
                name: "apply_pending_experiments_time",
                sendInPings: ["metrics"],
                lifetime: .ping,
                disabled: false
            )
            , .millisecond
        )

        /// Recorded when an application or library requests a feature configuration before
        /// the in memory cache has been populated from the database
        static let cacheNotReadyForFeature = EventMetricType<CacheNotReadyForFeatureExtra>( // generated from nimbus_health.cache_not_ready_for_feature
            CommonMetricData(
                category: "nimbus_health",
                name: "cache_not_ready_for_feature",
                sendInPings: ["events"],
                lifetime: .ping,
                disabled: true
            )
            , ["feature_id"]
        )

        /// Measures how long `fetchExperiments` takes.
        static let fetchExperimentsTime = TimingDistributionMetricType( // generated from nimbus_health.fetch_experiments_time
            CommonMetricData(
                category: "nimbus_health",
                name: "fetch_experiments_time",
                sendInPings: ["metrics"],
                lifetime: .ping,
                disabled: false
            )
            , .millisecond
        )

    }

}
