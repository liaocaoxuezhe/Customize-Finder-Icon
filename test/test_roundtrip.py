"""macOS integration test; Python 3.9+, standard library only."""
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]


def png(color):
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
    rows = (b'\0' + bytes(color) * 64) * 64
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', 64, 64, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This integration test requires macOS.')
    with tempfile.TemporaryDirectory(prefix='run-', dir=ROOT / 'test') as temp:
        d = Path(temp)
        binary = d / 'finder-icon'
        subprocess.run(['xcrun', 'swiftc', str(ROOT / 'scripts/finder_icon.swift'),
                        '-o', str(binary)], check=True)

        def run(*args, success=True):
            result = subprocess.run([str(binary), *map(str, args)],
                                    capture_output=True, text=True)
            assert (result.returncode == 0) == success, result.stdout + result.stderr

        red, blue = d / 'red.png', d / 'blue.png'
        red.write_bytes(png((240, 40, 40, 255)))
        blue.write_bytes(png((40, 40, 240, 255)))
        folder = d / '中文 folder'
        folder.mkdir()
        keep = folder / '保留.txt'
        keep.write_text('内容不变', encoding='utf-8')
        run('reference', folder, d / 'before.png')
        run('set', folder, red, d / 'default-backup')
        assert not json.loads((d / 'default-backup/state.json').read_text())['hadCustomIcon']
        run('reference', folder, d / 'red-applied.png')
        assert (d / 'red-applied.png').read_bytes() != (d / 'before.png').read_bytes()
        run('set', folder, blue, d / 'custom-backup')
        assert json.loads((d / 'custom-backup/state.json').read_text())['hadCustomIcon']
        assert (d / 'custom-backup/previous.tiff').stat().st_size > 0
        run('restore', folder, d / 'custom-backup')
        run('reference', folder, d / 'red-restored.png')
        assert (d / 'red-applied.png').read_bytes() == (d / 'red-restored.png').read_bytes()
        run('restore', folder, d / 'default-backup')
        run('reference', folder, d / 'default-restored.png')
        assert (d / 'before.png').read_bytes() == (d / 'default-restored.png').read_bytes()
        assert keep.read_text(encoding='utf-8') == '内容不变'
        run('set', folder, red, d / 'default-backup', success=False)
        run('set', folder, red, folder / 'nested-backup', success=False)
        run('set', folder, keep, d / 'bad-image', success=False)
        assert not (d / 'bad-image').exists()
        link = d / 'link'
        link.symlink_to(folder)
        run('set', link, red, d / 'bad-link', success=False)
        package = d / 'Example.app'
        package.mkdir()
        run('set', package, red, d / 'bad-package', success=False)
        run('reference', folder, d / 'before.png', success=False)
        file = d / '普通文件.txt'
        file.write_text('unchanged', encoding='utf-8')
        run('set', file, blue, d / 'file-backup')
        run('restore', file, d / 'default-backup', success=False)
        run('restore', file, d / 'file-backup')
        assert file.read_text(encoding='utf-8') == 'unchanged'
    print('PASS: file/folder round trips, custom/default restoration, Unicode paths, '
          'content preservation, invalid input rejection')


if __name__ == '__main__':
    main()
