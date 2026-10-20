import sys

from .build import main as build_main
from .report import main as report_main


def main(argv: list[str] | None = None) -> None:
    args = list(sys.argv[1:] if argv is None else argv)
    if args and args[0] == "build":
        build_main(args[1:])
        return
    report_main(args)


if __name__ == "__main__":
    main()
