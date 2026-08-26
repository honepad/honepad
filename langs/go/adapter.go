package main

import (
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"strings"
	"unicode"
)

type call struct {
	M string `json:"m"`
	A []any  `json:"a"`
	E any    `json:"e"`
}

type testCase struct {
	ID    string `json:"id"`
	Level int    `json:"level"`
	Calls []call `json:"calls"`
}

type failRow struct {
	Case     string `json:"case"`
	Index    int    `json:"index"`
	Method   string `json:"method"`
	Expected any    `json:"expected"`
	Actual   any    `json:"actual"`
}

type report struct {
	Passed int       `json:"passed"`
	Failed []failRow `json:"failed"`
}

func toPascal(name string) string {
	parts := strings.Split(name, "_")
	var b strings.Builder
	for _, part := range parts {
		if part == "" {
			continue
		}
		runes := []rune(part)
		runes[0] = unicode.ToUpper(runes[0])
		b.WriteString(string(runes))
	}
	return b.String()
}

func convertArg(arg any, dest reflect.Type) (reflect.Value, error) {
	if dest.Kind() == reflect.Interface && dest.NumMethod() == 0 {
		return reflect.ValueOf(arg), nil
	}
	switch dest.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		switch n := arg.(type) {
		case float64:
			return reflect.ValueOf(int64(n)).Convert(dest), nil
		case json.Number:
			i, err := n.Int64()
			if err != nil {
				return reflect.Value{}, err
			}
			return reflect.ValueOf(i).Convert(dest), nil
		case int:
			return reflect.ValueOf(n).Convert(dest), nil
		case int64:
			return reflect.ValueOf(n).Convert(dest), nil
		default:
			return reflect.Value{}, fmt.Errorf("cannot convert %T to %s", arg, dest)
		}
	case reflect.String:
		s, ok := arg.(string)
		if !ok {
			return reflect.Value{}, fmt.Errorf("cannot convert %T to string", arg)
		}
		return reflect.ValueOf(s), nil
	default:
		if arg == nil {
			return reflect.Zero(dest), nil
		}
		v := reflect.ValueOf(arg)
		if v.Type().ConvertibleTo(dest) {
			return v.Convert(dest), nil
		}
		return reflect.Value{}, fmt.Errorf("cannot convert %T to %s", arg, dest)
	}
}

func callMethod(obj any, name string, args []any) (any, error) {
	method := reflect.ValueOf(obj).MethodByName(name)
	if !method.IsValid() {
		return nil, fmt.Errorf("missing method %s", name)
	}
	sig := method.Type()
	if sig.NumIn() != len(args) {
		return nil, fmt.Errorf("%s wants %d args, got %d", name, sig.NumIn(), len(args))
	}
	in := make([]reflect.Value, len(args))
	for i, arg := range args {
		value, err := convertArg(arg, sig.In(i))
		if err != nil {
			return nil, err
		}
		in[i] = value
	}
	out := method.Call(in)
	if len(out) == 0 {
		return nil, nil
	}
	return out[0].Interface(), nil
}

func jsonEqual(actual, expected any) bool {
	left, err1 := json.Marshal(actual)
	right, err2 := json.Marshal(expected)
	if err1 != nil || err2 != nil {
		return false
	}
	return string(left) == string(right)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: adapter cases.json")
		os.Exit(2)
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	var cases []testCase
	if err := json.Unmarshal(data, &cases); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	failed := make([]failRow, 0)
	passed := 0
	for _, c := range cases {
		obj := NewTarget()
		ok := true
		for i, call := range c.Calls {
			name := toPascal(call.M)
			actual, err := callMethod(obj, name, call.A)
			if err != nil {
				failed = append(failed, failRow{
					Case:     c.ID,
					Index:    i,
					Method:   call.M,
					Expected: call.E,
					Actual:   "exc:" + err.Error(),
				})
				ok = false
				break
			}
			if !jsonEqual(actual, call.E) {
				failed = append(failed, failRow{
					Case:     c.ID,
					Index:    i,
					Method:   call.M,
					Expected: call.E,
					Actual:   actual,
				})
				ok = false
				break
			}
		}
		if ok {
			passed++
		}
	}
	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(report{Passed: passed, Failed: failed}); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if len(failed) > 0 {
		os.Exit(1)
	}
}
