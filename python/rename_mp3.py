import argparse
from pathlib import Path
from uuid import uuid4


def write_filename_list(directory: Path, filenames: list[Path]) -> Path:
    output_file = directory / "files.txt"
    contents = "".join(f"file '{filename.name}'\n" for filename in filenames)
    output_file.write_text(contents, encoding="utf-8")
    print(f"Saved filename list to {output_file}")
    return output_file


def rename_mp3_files(directory: Path, dry_run: bool = False) -> int:
    if not directory.is_dir():
        raise NotADirectoryError(f"Not a directory: {directory}")

    files = sorted(
        (
            path
            for path in directory.iterdir()
            if path.is_file() and path.suffix.casefold() == ".mp3"
        ),
        key=lambda path: (path.name.casefold(), path.name),
    )

    targets = [directory / f"{index}.mp3" for index in range(1, len(files) + 1)]
    write_filename_list(directory, targets)

    if not files:
        print(f"No MP3 files found in {directory}")
        return 0

    source_files = set(files)
    for target in targets:
        if target.exists() and target not in source_files:
            raise FileExistsError(f"Cannot rename: target already exists: {target}")

    print(f"Found {len(files)} MP3 file(s) in {directory}:")
    for source, target in zip(files, targets):
        print(f"  {source.name} -> {target.name}")

    if dry_run:
        return len(files)

    staged = [
        (source, directory / f".rename-mp3-{uuid4().hex}.tmp", target)
        for source, target in zip(files, targets)
    ]
    for _, temporary, _ in staged:
        if temporary.exists():
            raise FileExistsError(f"Temporary path already exists: {temporary}")

    staged_files: list[tuple[Path, Path, Path]] = []
    finalized_files: list[tuple[Path, Path, Path]] = []
    try:
        for item in staged:
            source, temporary, _ = item
            source.rename(temporary)
            staged_files.append(item)

        for item in staged:
            _, temporary, target = item
            temporary.rename(target)
            finalized_files.append(item)
    except OSError as error:
        rollback_errors: list[str] = []
        for source, temporary, target in reversed(finalized_files):
            try:
                target.rename(temporary)
            except OSError as rollback_error:
                rollback_errors.append(f"{target}: {rollback_error}")

        for source, temporary, _ in reversed(staged_files):
            if temporary.exists():
                try:
                    temporary.rename(source)
                except OSError as rollback_error:
                    rollback_errors.append(f"{source}: {rollback_error}")

        if rollback_errors:
            details = "; ".join(rollback_errors)
            raise RuntimeError(
                f"Renaming failed ({error}); rollback was incomplete: {details}"
            ) from error
        raise

    print(f"Renamed {len(files)} MP3 file(s).")
    return len(files)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Rename MP3 files in a folder to 1.mp3, 2.mp3, and so on."
    )
    parser.add_argument(
        "directory",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parent,
        help="Folder to scan (defaults to the folder containing this script).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List the planned renames without changing any files.",
    )
    args = parser.parse_args()
    rename_mp3_files(args.directory, args.dry_run)


if __name__ == "__main__":
    main()
