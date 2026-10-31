package main

import (
	"errors"
	"reflect"
	"testing"

	"github.com/spf13/cobra"
)

func TestPushStagesBeforeCommit(t *testing.T) {
	for _, override := range []bool{false, true} {
		a, calls, repo := testApp(t)
		args := []string{"push"}
		if override {
			t.Setenv("DOTFILES_DIR", "/missing")
			args = append(args, "--repo", repo)
		}
		if _, err := execute(a, args...); err != nil {
			t.Fatal(err)
		}
		want := []invocation{
			{repo, "git", []string{"add", "."}},
			{repo, "omp", []string{"--no-session", "commit", "--no-changelog", "--push"}},
		}
		if !reflect.DeepEqual(*calls, want) {
			t.Fatalf("calls=%#v, want=%#v", *calls, want)
		}
	}
}

func TestPushFailuresStopAndPropagate(t *testing.T) {
	for _, failingTool := range []string{"git", "omp"} {
		t.Run(failingTool, func(t *testing.T) {
			a, calls, _ := testApp(t)
			want := errors.New("command failed")
			a.run = func(_ *cobra.Command, dir, tool string, args []string) error {
				*calls = append(*calls, invocation{dir, tool, args})
				if tool == failingTool {
					return want
				}
				return nil
			}
			_, err := execute(a, "push")
			count := 2
			if failingTool == "git" {
				count = 1
			}
			if !errors.Is(err, want) || len(*calls) != count {
				t.Fatalf("err=%v, calls=%#v", err, *calls)
			}
		})
	}
}
