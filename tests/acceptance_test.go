package syslog_acceptance_test

import (
	"bufio"
	"bytes"
	"strconv"

	logrfc "github.com/jtarchie/syslog/pkg/log"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Impact on the local VM", func() {

	AfterEach(func() {
		Cleanup()
	})

	Context("When starting up", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/udp-blackbox.yml")
			AddFakeOldConfig()
			restartsession := BoshCmd("restart", "forwarder")
			Eventually(restartsession).Should(gexec.Exit(0))
		})

		It("Cleans up any files at old config file locations", func() {
			session := ForwarderSshCmd("stat /etc/rsyslog.d/rsyslog.conf || stat /etc/rsyslog.d/30-syslog-release.conf || stat /etc/rsyslog.d/20-syslog-release-custom-rules.conf")
			Eventually(session).Should(gbytes.Say("stat: cannot stat ‘/etc/rsyslog.d/rsyslog.conf’: No such file or directory"))
			Eventually(session).Should(gbytes.Say("stat: cannot stat ‘/etc/rsyslog.d/30-syslog-release.conf’: No such file or directory"))
			Eventually(session).Should(gbytes.Say("stat: cannot stat ‘/etc/rsyslog.d/20-syslog-release-custom-rules.conf’: No such file or directory"))
		})
	})

	Context("When processing logs from blackbox", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/udp-blackbox.yml")
		})

		It("doesn't write them to any of the standard linux logfiles", func() {
			By("waiting for logs to be forwarded")
			Eventually(WriteToTestFile("test-logger-isolation")).Should(gbytes.Say("test-logger-isolation"))

			By("checking that the logs don't appear in local logfiles")
			Expect(DefaultLogfiles()).NotTo(gbytes.Say("test-logger-isolation"))
		})
	})

	Context("When processing forwarded logs from jobs using logger", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/udp-blackbox.yml")
			SendLogMessage("test-logger-isolation")
		})

		It("doesn't write them to the logfiles specified in the stemcell config", func() {

			By("waiting for logs to be forwarded")
			Eventually(func() string {
				return ForwardedLogs()
			}).Should(ContainSubstring("test-logger-isolation"))

			By("checking that the logs don't appear in local logfiles")
			Expect(DefaultLogfiles()).NotTo(gbytes.Say("test-logger-isolation"))
		})
	})
})

var _ = Describe("Forwarding loglines to a TCP syslog drain", func() {
	TestSharedBehavior := func() {
		Context("When messages are written to UDP with logger", func() {
			It("receives messages in rfc5424 format on the configured drain", func() {
				SendLogMessage("test-rfc5424")
				Eventually(func() string {
					return ForwardedLogs()
				}).Should(ContainSubstring("test-rfc5424"))

				logs := bytes.NewBufferString(ForwardedLogs())
				reader := bufio.NewReader(logs)

				for {
					line, _, err := reader.ReadLine()
					Expect(err).ToNot(HaveOccurred())
					if len(line) == 0 {
						break
					}
					logLine, err := logrfc.Parse(line)
					Expect(err).ToNot(HaveOccurred())
					if string(logLine.Message()) == "test-rfc5424" {
						sdata := logLine.StructureData()
						Expect(string(sdata.ID())).To(Equal("instance@47450"))
						break
					}
				}
			})

			It("receives messages over 1k long on the configured drain", func() {
				message := counterString(1025, "A")
				SendLogMessage(message)
				Eventually(func() string {
					return ForwardedLogs()
				}).Should(ContainSubstring(message))
			})
		})

		Context("when a file is created in the watched directory structure", func() {
			BeforeEach(func() {
				session := ForwarderSshCmd("sudo touch /var/vcap/sys/log/syslog_forwarder/file.log")
				Eventually(session).Should(gexec.Exit(0))
			})

			It("forwards new lines written to the file through syslog", func() {
				Eventually(WriteToTestFile("test-blackbox-forwarding")).Should(gbytes.Say("test-blackbox-forwarding"))
			})
		})
	}

	Context("when file forwarding is configured to use UDP", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/udp-blackbox.yml")
		})
		AfterEach(func() {
			Cleanup()
		})

		TestSharedBehavior()
	})

	Context("when file forwarding is configured to use TCP", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/tcp-blackbox.yml")
		})
		AfterEach(func() {
			Cleanup()
		})

		TestSharedBehavior()
		It("fowards messages of over 1KB", func() {
			message := counterString(1025, "A")

			Eventually(WriteToTestFile(message)).Should(gbytes.Say(message))
		})
	})

	Context("when file forwarding is configured with good rules", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/good-rules.yml")
		})
		AfterEach(func() {
			Cleanup()
		})

		It("filters out messages that match the rule", func() {
			message := "This is a DEBUG message that we filter out"
			SendLogMessage(message)
			Consistently(func() string {
				return ForwardedLogs()
			}).ShouldNot(ContainSubstring(message))
		})

		TestSharedBehavior()
	})
})

var _ = Describe("When syslog is disabled", func() {
	Context("when the storer is configured to accept logs", func() {
		BeforeEach(func() {
			Cleanup()
			Deploy("manifests/disabled.yml")
		})

		It("does not forward logs", func() {
			SendLogMessage("test-logger-isolation")
			Consistently(func() string {
				return ForwardedLogs()
			}).Should(HaveLen(0))
		})

		It("doesn't start blackbox", func() {
			Expect(ForwarderMonitSummary()).ToNot(ContainSubstring("blackbox"))
		})
	})

	Context("when there is not configuration provided via links or properties", func() {
		BeforeEach(func() {
			Cleanup()
		})

		It("starts successfully", func() {
			Deploy("manifests/disabled-no-config.yml")
		})
	})
})

func counterString(l int, s string) string {
	counterstring := ""
	for len(counterstring) < l {
		counterstring += s
		counterstring += strconv.Itoa(len(counterstring))
	}

	return counterstring[:l]
}
