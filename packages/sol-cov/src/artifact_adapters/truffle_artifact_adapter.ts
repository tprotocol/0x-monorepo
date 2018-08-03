import { Compiler, CompilerOptions } from '@0xproject/sol-compiler';
import * as rimraf from 'rimraf';

import { ContractData } from '../types';

import { AbstractArtifactAdapter } from './abstract_artifact_adapter';
import { SolCompilerArtifactAdapter } from './sol_compiler_artifact_adapter';

export class TruffleArtifactAdapter extends AbstractArtifactAdapter {
    private readonly _solcVersion: string;
    private readonly _sourcesPath: string;
    /**
     * Instantiates a TruffleArtifactAdapter
     * @param artifactsPath Path to the truffle project's artifacts directory
     * @param sourcesPath Path to the truffle project's contract sources directory
     */
    constructor(sourcesPath: string, solcVersion: string) {
        super();
        this._solcVersion = solcVersion;
        this._sourcesPath = sourcesPath;
    }
    public async collectContractsDataAsync(): Promise<ContractData[]> {
        const artifactsDir = '.0x-artifacts';
        const compilerOptions: CompilerOptions = {
            contractsDir: this._sourcesPath,
            artifactsDir,
            compilerSettings: {
                outputSelection: {
                    ['*']: {
                        ['*']: ['abi', 'evm.bytecode.object', 'evm.deployedBytecode.object'],
                    },
                },
            },
            contracts: '*',
            solcVersion: this._solcVersion,
        };
        const compiler = new Compiler(compilerOptions);
        await compiler.compileAsync();
        const solCompilerArtifactAdapter = new SolCompilerArtifactAdapter(artifactsDir, this._sourcesPath);
        const contractsDataFrom0xArtifacts = await solCompilerArtifactAdapter.collectContractsDataAsync();
        rimraf.sync(artifactsDir);
        return contractsDataFrom0xArtifacts;
    }
}
