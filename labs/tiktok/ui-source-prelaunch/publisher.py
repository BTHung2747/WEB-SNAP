"""Host producer entry. Publishes only observation; no launch or permission issuer."""
import argparse,importlib.util,json,pathlib,sys
_path=pathlib.Path(__file__).resolve().parent.parent/'ui-source-glue'/'handshake.py'
_spec=importlib.util.spec_from_file_location('source_browser_protocol',_path)
protocol=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(protocol)
def publish(root,input_path,*,offline=False):
    root=pathlib.Path(root).resolve();observation=protocol.io.load(pathlib.Path(input_path))
    return protocol.publish_observation(root,observation,role='producer',offline=offline)
def main(argv=None):
    args=sys.argv[1:] if argv is None else argv
    if '--root' not in args or '--input' not in args:return 78
    parser=argparse.ArgumentParser();parser.add_argument('--root',required=True);parser.add_argument('--input',required=True);parser.add_argument('--offline-test-only',action='store_true')
    a=parser.parse_args(args)
    try:publish(a.root,a.input,offline=a.offline_test_only)
    except FileExistsError:print('{"status":"REJECTED","code":"ALREADY_PUBLISHED"}');return 23
    except protocol.Rejected:print('{"status":"REJECTED","code":"PROTOCOL_REJECTED"}');return 20
    except (OSError,ValueError,TypeError):print('{"status":"REJECTED","code":"INPUT_OR_FILESYSTEM"}');return 20
    print('{"status":"OBSERVATION_PUBLISHED","ownerDecision":"PENDING","completion":"PENDING"}');return 0
if __name__=='__main__':raise SystemExit(main())
